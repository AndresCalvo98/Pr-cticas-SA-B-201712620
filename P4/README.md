# Práctica 4 - Diseño y Toma de Decisiones

**Plataforma de Procesamiento Bancario (Arquitectura de Microservicios)**

Este repositorio contiene la implementación oficial de la **Práctica 4**, donde materializamos la arquitectura distribuida diseñada en la Práctica 3. El sistema abandona un enfoque monolítico para adoptar una red de microservicios contenerizados altamente cohesivos y débilmente acoplados, orquestados mediante **Docker Compose** y expuestos a través de un **API Gateway**.

## 🚀 Tecnologías y Arquitectura

- **Lenguajes de Programación**: Node.js (JavaScript) y Go (Golang).
- **Microservicios Implementados**:
  1. `auth-service` (Node.js): Integración directa de la Práctica 2.
  2. `transaction-service` (Go): Lógica de carga de archivos y validación inicial.
  3. `approval-service` (Node.js): Orquestación del flujo de 3 pasos (Maker/Checker/Authorizer).
  4. `notification-service` (Node.js): Procesamiento asíncrono de alertas.
- **Enrutamiento (API Gateway)**: Nginx (Proxy Inverso).
- **Consultas Avanzadas**: **GraphQL** nativo implementado en los servicios `transaction-service` y `approval-service`.
- **Contratos API**: Documentación de endpoints provista en el archivo `postman_collection.json`.


## 📂 Organización del Repositorio

El repositorio está estructurado de la siguiente manera para separar responsabilidades y facilitar el despliegue independiente de cada servicio:

*   **`/api-gateway`**: Contiene la configuración de NGINX que actúa como proxy inverso y punto de entrada único para la plataforma.
*   **`/approval-service`**: Microservicio en Node.js encargado de orquestar el flujo de aprobación de 3 pasos (Maker-Checker-Authorizer), implementando consultas nativas en GraphQL y REST.
*   **`/auth-service`**: Microservicio en Node.js que gestiona la autenticación y autorización (Integración de la Práctica 2).
*   **`/notification-service`**: Microservicio en Node.js dedicado al procesamiento asíncrono y envío de alertas.
*   **`/transaction-service`**: Microservicio en Go encargado de la carga de archivos, validación inicial de transacciones y persistencia.
*   **`docker-compose.yml`**: Archivo de orquestación que define y levanta todos los contenedores de la solución.
*   **`postman_collection.json`**: Colección de pruebas de Postman que documenta los contratos de los endpoints (REST y GraphQL) de los microservicios.
*   **`README.md`**: Este documento, que incluye la explicación de la arquitectura, estructura y aplicación de los principios SOLID.

---

## 🏛️ Aplicación de Principios SOLID

La calidad del código es una prioridad en arquitecturas modernas. A lo largo del desarrollo de estos microservicios, se implementaron rigurosamente los 5 principios SOLID. A continuación se presenta la evidencia técnica extraída directamente del código fuente:

### 1. Single Responsibility Principle (SRP)
**Definición:** Un módulo o clase debe tener una única razón para cambiar (una sola responsabilidad).

**Evidencia (Go):** En el `transaction-service`, el enrutamiento HTTP y la lógica de negocio están estrictamente separados.
- `main.go`: Su única responsabilidad es arrancar el servidor e inyectar dependencias.
- `rest_handler.go`: Se encarga *exclusivamente* de leer requests y escribir respuestas JSON.
- `transaction_service.go`: Maneja la lógica de validación de los lotes.

```go
// fragmento: main.go
func main() {
	storage := &services.MockStorage{}
	txService := services.NewTransactionService(storage)
	restHandler := handlers.NewRestHandler(txService)
	http.HandleFunc("/api/transactions/upload", restHandler.UploadCSV)
	http.ListenAndServe(":4001", nil)
}
```

### 2. Open/Closed Principle (OCP)
**Definición:** El software debe estar abierto para extensión, pero cerrado para modificación.

**Evidencia (Node.js):** En el `approval-service`, las reglas de autorización se gestionan mediante el patrón de diseño *Strategy*. Si mañana el banco requiere un nuevo paso en el flujo (ej. "Auditor Financiero"), **no** modificaremos la clase `ApprovalContext` ni las rutas existentes; simplemente crearemos una nueva clase `AuditorStrategy` que herede de `ApprovalStrategy`.

```javascript
// fragmento: approvalStrategy.js
class ApprovalStrategy {
    approve(batchId) { throw new Error("Implementar"); }
}

class CheckerStrategy extends ApprovalStrategy {
    approve(batchId) { return "PENDING_AUTHORIZER"; }
}

class AuthorizerStrategy extends ApprovalStrategy {
    approve(batchId) { return "APPROVED"; }
}
```

### 3. Liskov Substitution Principle (LSP)
**Definición:** Las clases derivadas deben poder sustituir a sus clases base sin alterar el correcto funcionamiento del sistema.

**Evidencia (Node.js):** En el `notification-service`, contamos con una abstracción base `Notificator`. El sistema puede instanciar de forma transparente un `EmailNotificator` o un `SMSNotificator`, y ambos responderán correctamente al método `.send(message)`. El controlador ignora los detalles de implementación subyacentes.

```javascript
// fragmento: server.js (Notification Service)
let notificator = type === 'SMS' ? new SMSNotificator() : new EmailNotificator();

// Sustitución de Liskov en acción:
notificator.send(message); 
```

### 4. Interface Segregation Principle (ISP)
**Definición:** Los clientes no deben verse obligados a depender de interfaces que no utilizan. Es mejor tener muchas interfaces específicas.

**Evidencia (Go):** En lugar de forzar a los servicios a implementar una interfaz monolítica gigante llamada `Database`, el `transaction-service` divide el contrato en interfaces minúsculas y precisas: `TransactionSaver` y `TransactionReader`. 

```go
// fragmento: transaction_service.go
type TransactionSaver interface {
	SaveBatch(batchID string, data string) error
}

type TransactionReader interface {
	GetBatchStatus(batchID string) string
}
```

### 5. Dependency Inversion Principle (DIP)
**Definición:** Los módulos de alto nivel no deben depender de los módulos de bajo nivel; ambos deben depender de abstracciones.

**Evidencia (Go):** El `TransactionService` no crea instancias de bases de datos internas (como MySQL o MongoDB). En lugar de eso, exige que se le pase a través de su constructor una abstracción que cumpla con las interfaces requeridas. Esto facilita enormemente el testing, permitiéndonos inyectar un `MockStorage` durante el desarrollo local sin cambiar el código de negocio.

```go
// fragmento: transaction_service.go
type TransactionService struct {
	saver TransactionSaver
}

// Inyección de la dependencia vía constructor
func NewTransactionService(storage TransactionSaver) *TransactionService {
	return &TransactionService{
		saver: storage,
	}
}
```

---

## ⚙️ Instrucciones de Despliegue Local

1. Asegúrate de que el puerto `8080` esté libre en tu máquina anfitriona.
2. Posiciónate en la carpeta `P4` (donde reside el archivo `docker-compose.yml`).
3. Ejecuta el comando de compilación y levantamiento orquestado:
   ```bash
   docker-compose up -d --build
   ```
4. Explora los endpoints de la API (tanto REST como GraphQL) importando el archivo `postman_collection.json` en Postman. Todos los servicios están abstraídos detrás de `localhost:8080`.
