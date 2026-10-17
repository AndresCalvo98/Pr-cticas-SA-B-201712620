const express = require('express');
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
  serviceName: 'sa-auth-service'
});
sdk.start();

const tracer = opentelemetry.trace.getTracer('sa-auth-service');

// 2. Registro de métricas Prometheus y métricas de negocio
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total de peticiones HTTP en auth-service',
  labelNames: ['method', 'route', 'status', 'service'],
  registers: [register]
});

const httpRequestDurationSeconds = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duración de peticiones HTTP en auth-service',
  labelNames: ['method', 'route', 'status', 'service'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5],
  registers: [register]
});

// Métrica de negocio: Usuarios autenticados exitosamente
const usuariosAutenticadosTotal = new client.Counter({
  name: 'usuarios_autenticados_total',
  help: 'Métrica de negocio: Cantidad total de inicios de sesión y validaciones exitosas',
  labelNames: ['rol', 'resultado'],
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
    service: 'sa-auth-service',
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
  
  // Extraer contexto W3C (traceparent)
  const activeContext = opentelemetry.propagation.extract(opentelemetry.context.active(), req.headers);

  const span = tracer.startSpan(`auth-service ${req.method} ${req.path}`, {
    attributes: {
      'http.method': req.method,
      'http.target': req.path,
    }
  }, activeContext);

  opentelemetry.context.with(opentelemetry.trace.setSpan(activeContext, span), () => {
    res.on('finish', () => {
      const duration = (Date.now() - start) / 1000;
      span.setAttribute('http.status_code', res.statusCode);
      span.end();

      httpRequestsTotal.inc({ method: req.method, route: req.path, status: res.statusCode, service: 'sa-auth-service' });
      httpRequestDurationSeconds.observe({ method: req.method, route: req.path, status: res.statusCode, service: 'sa-auth-service' }, duration);

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

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'UP', service: 'sa-auth-service' });
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.post('/login', (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    usuariosAutenticadosTotal.inc({ rol: 'desconocido', resultado: 'fallido' });
    logJSON('WARN', 'Intento de inicio de sesión fallido: credenciales vacías', { username });
    return res.status(400).json({ error: 'Usuario y contraseña requeridos' });
  }

  usuariosAutenticadosTotal.inc({ rol: 'estudiante', resultado: 'exitoso' });
  logJSON('INFO', `Usuario autenticado exitosamente: ${username}`, { username, carnet: '201712620' });
  res.status(200).json({ token: 'jwt-token-simulado-201712620', user: username });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logJSON('INFO', `sa-auth-service iniciado y escuchando en el puerto ${PORT}`);
});
