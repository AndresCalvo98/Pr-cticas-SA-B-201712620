const express = require('express');
const axios = require('axios');
const opentelemetry = require('@opentelemetry/api');
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const client = require('prom-client');

// 1. Inicialización de OpenTelemetry SDK
const traceExporter = new OTLPTraceExporter({
  url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector.observabilidad.svc.cluster.local:4318/v1/traces',
});

const sdk = new NodeSDK({
  traceExporter,
  instrumentations: [getNodeAutoInstrumentations()],
  serviceName: 'sa-api-gateway'
});
sdk.start();

const tracer = opentelemetry.trace.getTracer('sa-api-gateway');

// 2. Métricas de Prometheus y de Negocio
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total de peticiones HTTP recibidas',
  labelNames: ['method', 'route', 'status', 'service'],
  registers: [register]
});

const httpRequestDurationSeconds = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duración de peticiones HTTP en segundos',
  labelNames: ['method', 'route', 'status', 'service'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [register]
});

// Métrica de negocio 2: Pagos o peticiones rechazadas
const pagosRechazadosTotal = new client.Counter({
  name: 'pagos_rechazados_total',
  help: 'Métrica de negocio: Total de pagos y autorizaciones rechazadas',
  labelNames: ['motivo', 'servicio'],
  registers: [register]
});

const app = express();
app.use(express.json());

// 3. Logger estructurado JSON correlacionado con trace_id
function logJSON(level, message, extra = {}) {
  const currentSpan = opentelemetry.trace.getActiveSpan();
  const spanContext = currentSpan ? currentSpan.spanContext() : null;
  const traceId = spanContext ? spanContext.traceId : '00000000000000000000000000000000';
  const spanId = spanContext ? spanContext.spanId : '0000000000000000';

  const logEntry = {
    timestamp: new Date().toISOString(),
    level,
    service: 'sa-api-gateway',
    trace_id: traceId,
    span_id: spanId,
    message,
    ...extra
  };
  console.log(JSON.stringify(logEntry));
}

// Middleware de observabilidad y propagación de contexto W3C
app.use((req, res, next) => {
  const start = Date.now();
  
  // Extraer contexto W3C traceparent si viene en los encabezados
  const activeContext = opentelemetry.propagation.extract(opentelemetry.context.active(), req.headers);

  const span = tracer.startSpan(`HTTP ${req.method} ${req.path}`, {
    attributes: {
      'http.method': req.method,
      'http.url': req.url,
      'http.target': req.path,
    }
  }, activeContext);

  opentelemetry.context.with(opentelemetry.trace.setSpan(activeContext, span), () => {
    res.on('finish', () => {
      const duration = (Date.now() - start) / 1000;
      span.setAttribute('http.status_code', res.statusCode);
      span.end();

      httpRequestsTotal.inc({ method: req.method, route: req.path, status: res.statusCode, service: 'sa-api-gateway' });
      httpRequestDurationSeconds.observe({ method: req.method, route: req.path, status: res.statusCode, service: 'sa-api-gateway' }, duration);

      logJSON(res.statusCode >= 500 ? 'ERROR' : 'INFO', `HTTP ${req.method} ${req.path} -> ${res.statusCode}`, {
        http_method: req.method,
        http_path: req.path,
        http_status: res.statusCode,
        duration_seconds: duration
      });
    });

    next();
  });
});

// Rutas de aplicación
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'UP', service: 'sa-api-gateway' });
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Forwarding con inyección de contexto W3C traceparent
app.all('/api/auth/*', async (req, res) => {
  const targetUrl = `http://sa-platform-app-auth-service:3000${req.path.replace('/api/auth', '')}`;
  const headers = { ...req.headers };
  
  // Inyectar contexto W3C (traceparent)
  opentelemetry.propagation.inject(opentelemetry.context.active(), headers);

  try {
    const response = await axios({
      method: req.method,
      url: targetUrl,
      headers,
      data: req.body
    });
    res.status(response.status).json(response.data);
  } catch (error) {
    const status = error.response ? error.response.status : 502;
    logJSON('ERROR', `Error al comunicar con auth-service: ${error.message}`, { targetUrl, status });
    res.status(status).json(error.response ? error.response.data : { error: error.message });
  }
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  logJSON('INFO', `sa-api-gateway iniciado y escuchando en el puerto ${PORT}`);
});
