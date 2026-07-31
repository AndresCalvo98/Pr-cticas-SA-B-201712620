# Práctica P1 - Principios SOLID y uso responsable de IA

API REST desarrollada en TypeScript con Express y PostgreSQL para administrar solicitudes operativas de una academia ficticia. El objetivo de esta práctica no fue solo “hacer funcionar” una API, sino estructurar una solución mantenible, validada y explicable: cada decisión técnica quedó separada por responsabilidad, cada entrada se valida antes de persistirla y cada interacción con la base de datos se realiza con consultas parametrizadas.

## Propósito de la solución

La aplicación resuelve el ciclo básico de una solicitud operativa:

- consultar todas las solicitudes,
- crear una nueva solicitud,
- actualizar completamente una solicitud,
- actualizar únicamente su estado,
- eliminar una solicitud.

Además, incorpora una documentación explícita de los principios SOLID y un registro de uso de IA con revisión crítica, porque la rúbrica no evalúa únicamente funcionalidad: también evalúa criterio de diseño, claridad documental y conciencia de seguridad.

## Alcance técnico

- Backend en TypeScript.
- Servidor HTTP con Express.
- Persistencia en PostgreSQL o Supabase.
- Separación por capas: controller, service, repository, models, dtos, interfaces, routes y config.
- Validación de datos en la capa de negocio.
- Consultas SQL parametrizadas para reducir riesgo de inyección.

## Estructura del proyecto

- `src/controllers`: capa de entrada HTTP.
- `src/services`: reglas de negocio, validaciones y coordinación.
- `src/repositories`: acceso a PostgreSQL.
- `src/interfaces`: contratos para inversión de dependencias.
- `src/models`: tipos del dominio.
- `src/dtos`: estructuras de entrada.
- `src/routes`: definición de endpoints.
- `src/config`: variables de entorno, conexión y SQL base.
- `src/utils`: manejo de errores y helpers transversales.

## Estado de la entrega

- La API compila correctamente con `npm run build`.
- El servidor arranca con `npm run dev`.
- El POST, PUT, PATCH, DELETE y GET están implementados.
- La persistencia está conectada a Supabase.
- La documentación académica está incluida en este archivo y en [PROMPTS.md](PROMPTS.md).
- La guía de pruebas está en [VERIFICACION.md](VERIFICACION.md).

## Requisitos previos

- Node.js 20 o superior.
- Acceso a la base de datos PostgreSQL/Supabase.
- Archivo `.env` en la raíz del proyecto con la variable `DATABASE_URL`.

## Configuración de entorno

Crear el archivo `.env` en la raíz del proyecto con contenido equivalente a:

```dotenv
PORT=3000
DATABASE_URL=postgresql://usuario:contraseña@host:5432/base_de_datos
```

## Esquema de base de datos

El archivo [src/config/schema.sql](src/config/schema.sql) define la tabla `operational_requests` con `id` autoincremental, restricciones de prioridad y costo, y estados válidos limitados a `registrada`, `en_proceso` y `finalizada`.

## Ejecución local

1. Instalar dependencias con `npm install`.
2. Configurar el archivo `.env`.
3. Crear la tabla ejecutando `src/config/schema.sql` en PostgreSQL o Supabase.
4. Compilar con `npm run build`.
5. Levantar la API con `npm run dev`.

## Endpoints disponibles

Base URL: `/api/solicitudes`

- `GET /` obtiene todas las solicitudes.
- `POST /` registra una nueva solicitud.
- `PUT /:id` reemplaza completamente una solicitud existente.
- `PATCH /:id/status` actualiza únicamente el estado.
- `DELETE /:id` elimina una solicitud.

### Ejemplo de creación

```json
{
  "titulo": "Adquisición de nuevo servidor",
  "areaSolicitante": "Infraestructura TI",
  "prioridad": 3,
  "costoEstimado": 2500,
  "estado": "registrada"
}
```

## Validaciones implementadas

- `titulo` y `areaSolicitante` deben tener al menos 3 caracteres.
- `prioridad` debe ser un entero entre 1 y 5.
- `costoEstimado` debe ser mayor o igual a 0.
- `estado` solo admite `registrada`, `en_proceso` o `finalizada`.
- `id` de las rutas debe ser numérico.
- El cuerpo de solicitud no puede venir vacío en POST, PUT o PATCH.

## SOLID aplicado en el proyecto

Para esta práctica traté de no quedarme solo con la definición teórica de SOLID. La idea fue llevar cada principio a una decisión concreta dentro del proyecto, de forma que el código muestre claramente qué hace cada parte y por qué está separada así. En vez de mezclar validación, persistencia y respuestas HTTP en un solo bloque, organicé el backend en capas para que cada pieza tenga una responsabilidad clara y sea más fácil de mantener.

### 1) Responsabilidad Única

Este principio me ayudó a evitar el error más común en una API pequeña: poner toda la lógica en el controlador. Aquí lo dividí de esta manera: el controlador solo recibe la petición y devuelve la respuesta, el servicio toma las decisiones de negocio y el repositorio habla con la base de datos. Eso hace que cada clase tenga una sola razón para cambiar.

Dónde lo apliqué:

- [src/controllers/operational-request.controller.ts](src/controllers/operational-request.controller.ts)
- [src/services/operational-request.service.ts](src/services/operational-request.service.ts)
- [src/repositories/postgres-operational-request.repository.ts](src/repositories/postgres-operational-request.repository.ts)

Evidencia real:

```ts
// src/controllers/operational-request.controller.ts
create = async (request: Request, response: Response): Promise<void> => {
  const requestCreated = await this.service.create(request.body);
  response.status(201).json({ data: requestCreated });
};
```

```ts
// src/services/operational-request.service.ts
async updateStatus(id: string, dto: UpdateOperationalRequestStatusDto): Promise<OperationalRequest> {
  this.validateId(id);
  this.assertBody(dto);
  const estado = this.validateStatus(dto.estado);
  const updated = await this.repository.updateStatus(id, estado);
  if (!updated) {
    throw new HttpError(404, "Solicitud operativa no encontrada");
  }
  return updated;
}
```

### 2) Abierto/Cerrado

Yo entendí este principio como la idea de que una clase no debería obligarme a reescribir su lógica solo porque cambie una implementación interna. En este proyecto el servicio trabaja contra una interfaz, no contra una clase concreta de PostgreSQL. Si mañana cambiara de base de datos o de estrategia de persistencia, la lógica del servicio seguiría casi igual.

Dónde lo apliqué:

- [src/interfaces/operational-request-repository.ts](src/interfaces/operational-request-repository.ts)
- [src/services/operational-request.service.ts](src/services/operational-request.service.ts)

Evidencia real:

```ts
// src/interfaces/operational-request-repository.ts
export interface OperationalRequestRepository {
  findAll(): Promise<OperationalRequest[]>;
  findById(id: string): Promise<OperationalRequest | null>;
  create(input: {
    titulo: string;
    areaSolicitante: string;
    prioridad: number;
    costoEstimado: number;
    estado: RequestStatus;
  }): Promise<OperationalRequest>;
}
```

### 3) Sustitución de Liskov

Este principio me parece importante porque evita que una implementación “rompa” el comportamiento esperado solo por cambiar la clase concreta. En otras palabras, si el servicio espera un repositorio, cualquier repositorio que cumpla el contrato debe funcionar sin sorpresas. Por eso cuidé que la interfaz describa exactamente lo que el servicio necesita y no dependa de detalles internos.

Dónde lo apliqué:

- [src/interfaces/operational-request-repository.ts](src/interfaces/operational-request-repository.ts)
- [src/services/operational-request.service.ts](src/services/operational-request.service.ts)

Evidencia real:

```ts
// src/services/operational-request.service.ts
constructor(private readonly repository: OperationalRequestRepository) {}
```

### 4) Segregación de Interfaces

Yo lo interpreté como una forma de no obligar a los consumidores a depender de cosas que no necesitan. En esta práctica eso se nota sobre todo en el caso del cambio de estado: no tiene sentido exigir el objeto completo de la solicitud si solo quiero modificar `estado`. Por eso separé ese caso en un DTO específico y en una ruta propia.

Dónde lo apliqué:

- [src/dtos/update-operational-request-status.dto.ts](src/dtos/update-operational-request-status.dto.ts)
- [src/routes/operational-request.routes.ts](src/routes/operational-request.routes.ts)

Evidencia real:

```ts
// src/routes/operational-request.routes.ts
router.patch("/:id/status", asyncHandler(controller.updateStatus));
```

### 5) Inversión de Dependencias

Para mí, este principio fue el más importante en la arquitectura: las decisiones principales del sistema no deben depender de detalles de infraestructura, sino de abstracciones. En este proyecto la lógica de negocio no conoce cómo se conecta PostgreSQL, solo sabe que existe un repositorio que cumple un contrato. Eso me permitió mantener el centro del sistema limpio y aislado del detalle técnico.

Dónde lo apliqué:

- [src/services/operational-request.service.ts](src/services/operational-request.service.ts)
- [src/repositories/postgres-operational-request.repository.ts](src/repositories/postgres-operational-request.repository.ts)

Evidencia real:

```ts
// src/repositories/postgres-operational-request.repository.ts
export class PostgresOperationalRequestRepository implements OperationalRequestRepository {
  constructor(private readonly pool: Pool) {}
}
```

## Reflexión breve sobre SOLID

Después de aplicar estos principios, la diferencia más clara que noté fue en la claridad del proyecto. El código dejó de sentirse como una secuencia de instrucciones pegadas una detrás de otra, y pasó a tener intención: cada archivo responde a una necesidad concreta. Eso no solo ayuda a que funcione hoy, sino a que sea entendible mañana por otra persona o por mí mismo cuando tenga que corregirlo.

## Seguridad y limpieza del código

La solución se revisó con un criterio pragmático:

- Se validan entradas antes de persistir.
- Se usan consultas parametrizadas con `pg`.
- Se responde con errores HTTP explícitos y controlados.
- Se evita mezclar reglas de negocio con acceso a datos.
- Se mantiene el endpoint de estado separado del update completo.

## Seguridad y limpieza del código

La solución se revisó con un criterio pragmático:

- Se validan entradas antes de persistir.
- Se usan consultas parametrizadas con `pg`.
- Se responde con errores HTTP explícitos y controlados.
- Se evita mezclar reglas de negocio con acceso a datos.
- Se mantiene el endpoint de estado separado del update completo.

## Uso de IA

Sí se utilizó IA, pero no como sustituto de criterio. La IA sirvió para acelerar la generación inicial y para discutir alternativas de estructura; después se revisó el resultado, se corrigieron riesgos y se ajustó el diseño para que el código fuera consistente con la práctica y con la base de datos real.

El detalle de prompts, respuestas y ajustes está documentado en [PROMPTS.md](PROMPTS.md).

## Verificación final

Antes de entregar, revisa [VERIFICACION.md](VERIFICACION.md) para validar:

- compilación,
- arranque,
- CRUD,
- casos negativos,
- persistencia en Supabase.
