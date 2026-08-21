# 🚀 Guía de Endpoints del Sistema

Este documento lista todos los endpoints (REST y GraphQL) expuestos por el sistema a través del API Gateway, así como la ubicación exacta dentro del código fuente donde están implementados. Esto te servirá para mostrarlos rápidamente durante la calificación.

Todos los endpoints son accesibles a través del **API Gateway** en `http://localhost:8080`.

---

## 1. Auth Service
Servicio encargado de la seguridad perimetral y validación de tokens.

*   **Endpoint:** `POST /api/auth/authorize`
*   **Tipo:** REST
*   **Descripción:** Recibe información (roles/paths) y devuelve si la acción está autorizada.
*   **Ubicación en el código:** Este código se hereda directamente de la **Práctica 2** (`P2/authz-service/server.js`).

---

## 2. Transaction Service (Go)
Servicio para la carga de transacciones masivas.

### Upload CSV
*   **Endpoint:** `POST /api/transactions/upload`
*   **Tipo:** REST
*   **Descripción:** Permite subir un archivo CSV para su validación inicial y almacenamiento.
*   **Ubicación en el código:** `P4/transaction-service/main.go` (Línea 22) y la lógica está en la carpeta `handlers/`.

### Consultar Estado de Lote (Batch)
*   **Endpoint:** `GET /graphql/transactions`
*   **Tipo:** GraphQL
*   **Query de ejemplo:** `{ batchStatus(batchId: "batch-123") }`
*   **Descripción:** Consulta el estado de una transacción mediante GraphQL.
*   **Ubicación en el código:** `P4/transaction-service/main.go` (Línea 23) y manejado en `handlers/`.

---

## 3. Approval Service (Node.js)
Servicio que orquesta el flujo de aprobación de 3 pasos (Maker, Checker, Authorizer).

### Aprobar Lote
*   **Endpoint:** `POST /api/approvals/:batchId`
*   **Tipo:** REST
*   **Descripción:** Avanza el estado de un lote dependiendo del rol del usuario que lo aprueba.
*   **Ubicación en el código:** `P4/approval-service/server.js` (Línea 17)

### Consultar Workflow (Flujo de Aprobación)
*   **Endpoint:** `GET /graphql/approvals`
*   **Tipo:** GraphQL
*   **Query de ejemplo:** `{ getWorkflow(batchId: "batch-123") { batchId, status } }`
*   **Descripción:** Obtiene el estado actual del flujo de aprobación de un lote específico.
*   **Ubicación en el código:** `P4/approval-service/server.js` (Líneas 41 a la 59)

---

## 💡 Tip para la Calificación
Puedes utilizar el archivo `postman_collection.json` incluido en la carpeta `P4` para importar todos estos endpoints directamente a Postman y ejecutarlos frente al evaluador sin tener que escribirlos manualmente.
