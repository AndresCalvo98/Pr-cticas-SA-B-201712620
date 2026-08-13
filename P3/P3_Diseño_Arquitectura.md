# Diseño de Arquitectura - Práctica 3

Este documento presenta el diseño de la arquitectura para el nuevo sistema de procesamiento de transacciones de la institución bancaria, pasando de un esquema monolítico a uno basado en microservicios para soportar épocas de alta demanda.

## 1. Diagrama de Arquitectura General

El sistema ha sido diseñado utilizando el patrón **API Gateway** para enrutar las peticiones, **OAuth 2.0** para la seguridad perimetral, y **RabbitMQ** como bus de mensajes para asegurar el desacoplamiento y el procesamiento asíncrono de tareas pesadas (como validaciones de CSV y comunicación con el core bancario).

![Diagrama de Arquitectura General](<Img/Diagrama Arquitectura General.jpg>)

*Nota: Todos los servicios emiten logs asíncronos hacia el sistema de Logging Centralizado.*

---

## 2. Diagrama de Componentes UML

Este diagrama muestra la relación entre los microservicios, el API Gateway y los sistemas externos.

![Diagrama de Componentes UML](<Img/Diagrama de Componentes UML.jpg>)

---

## 3. Uso e Integración del Servicio de Autenticación (Práctica 2)

Se reutiliza el módulo desarrollado en la Práctica 2 y se integra un servidor OAuth corporativo.

1. **Tokens de corta vida y JWT:** El servicio OAuth corporativo emite tokens de acceso (JWT) con un tiempo de vida de 12 horas.
2. **Validación en el API Gateway:** El API Gateway intercepta todas las peticiones entrantes. Antes de enrutarlas, verifica la validez del token interactuando (o cacheando llaves públicas) con el `Auth Service`.
3. **Manejo de Roles:** El token incluye *claims* con los roles del usuario (ej. `Maker`, `Checker`, `Authorizer`). Los microservicios extraen estos roles del encabezado `Authorization` para aplicar reglas de negocio locales sin consultar constantemente la base de datos de usuarios.

---

## 4. Diseño de Microservicios: Responsabilidades y Diagramas UML

Hemos separado la arquitectura en **4 microservicios funcionales**:

### 4.1. Auth Service
- **Responsabilidad:** Gestionar usuarios, autenticación, autorización y emisión/validación de tokens JWT.

#### Diagrama de Clases UML
![Auth Service - Diagrama de Clases](<Img/Diagrama de Clases UML Auth Service.jpg>)

#### Diagrama Entidad-Relación (ER)
![Auth Service - Diagrama ER](<Img/Diagrama Entidad-Relación (ER) Auth Service.jpg>)

### 4.2. Transaction Service
- **Responsabilidad:** Recepción de archivos CSV, validación de reglas de negocio (saldos, cuentas, prevención de fraude), almacenamiento del CSV en Cloud Storage y persistencia inicial de las transacciones (lotes).

#### Diagrama de Clases UML
![Transaction Service - Diagrama de Clases](<Img/Diagrama de Clases UML Transaction Service.jpg>)

#### Diagrama Entidad-Relación (ER)
![Transaction Service - Diagrama ER](<Img/Diagrama Entidad-Relación (ER) Transaction Service.jpg>)

### 4.3. Approval Service
- **Responsabilidad:** Orquestar el flujo de aprobación de 3 pasos (Maker-Checker-Authorizer). Mantener el estado de cada lote. Enviar las transacciones aprobadas al Core Bancario.

#### Diagrama de Clases UML
![Approval Service - Diagrama de Clases](<Img/Diagrama de Clases UML Approval Service.jpg>)

#### Diagrama Entidad-Relación (ER)
*Al utilizar MongoDB (NoSQL), modelamos colecciones en lugar de tablas relacionales estrictas.*
![Approval Service - Diagrama ER](<Img/Diagrama Entidad-Relación (ER) Approval Service.jpg>)



### 4.4. Notification Service (Recomendado)
- **Responsabilidad:** Escuchar eventos asíncronos (como "Lote Aprobado") y enviar correos electrónicos a los clientes/beneficiarios. 
*(No requiere almacenamiento persistente complejo más allá de logs).*

---

## 5. Diagramas de Secuencia (Flujos Críticos)

### 5.1. Flujo de Carga y Aprobación de 3 Pasos (Maker-Checker-Authorizer)

Este diagrama documenta cómo funciona el flujo de 3 pasos y la comunicación entre servicios.

![Diagrama de Secuencia](<Img/Diagramas de Secuencia.jpg>)

---

## 6. Documentación Estratégica

### 6.1. Flujo de Aprobación de 3 Pasos (Explicación)
El esquema de control **Maker-Checker-Authorizer** garantiza la segregación de funciones:
1. **Maker (Creador):** Un empleado operativo carga el archivo CSV con transacciones masivas. El sistema hace validaciones automáticas iniciales (montos, formato, fraude). Si pasa, queda en estado "Pendiente de Revisión".
2. **Checker (Revisor):** Un supervisor de primer nivel revisa el lote. Verifica que la cantidad de registros y montos cuadren con los documentos físicos/respaldos. Aprueba el lote, pasándolo a estado "Pendiente de Autorización".
3. **Authorizer (Autorizador):** Un gerente (rol gerencial) aplica la firma final. Al autorizar, el sistema automáticamente dispara la petición asíncrona hacia el Core Bancario para liquidar los fondos y notifica a los usuarios involucrados.

### 6.2. Estrategia de Almacenamiento de Archivos CSV
- **Decisión:** `Cloud Storage (Ej. AWS S3 o Google Cloud Storage)`.
- **Justificación:** Almacenar los archivos físicos en disco duro o base de datos relacional dentro de un contenedor degradaría el rendimiento del microservicio. Cloud Storage ofrece almacenamiento ilimitado, durabilidad del 99.99999%, y permite generar enlaces seguros o pre-firmados para la descarga del historial. El Transaction Service solo guarda la URL (referencia) al archivo.

### 6.3. Estrategia de Comunicación entre Servicios
- **REST (Síncrono):** Utilizado de **Cliente a Gateway** y de **Gateway a Microservicios** (frontend pidiendo datos, usuarios haciendo click en botones de aprobar).
- **Mensajería Asíncrona (RabbitMQ):** Utilizado de **Microservicio a Microservicio**. Por ejemplo, cuando se carga un archivo pesado o cuando se autoriza un lote. En lugar de que el *Approval Service* espere enviando 5,000 correos (lo que provocaría un timeout), simplemente publica un mensaje `BATCH_PROCESSED` en RabbitMQ, y el *Notification Service* se encarga de enviar los correos en segundo plano a su propio ritmo.

### 6.4. Estrategia de Logging Centralizado
- **Decisión:** Stack ELK (Elasticsearch, Logstash, Kibana) o Grafana Loki.
- **Justificación:** Al tener 4 contenedores (servicios) ejecutándose de manera independiente, leer los logs con `docker logs` de forma aislada hace imposible seguir el rastro de una transacción (Traceability). Se implementará un **Correlation ID** (Ej. un UUID) en el Gateway. Cada microservicio que procese la petición incluirá este UUID en sus logs. Todos los contenedores enviarán sus logs a un volumen centralizado o servidor Elasticsearch, permitiendo buscar un `Correlation ID` y ver el flujo completo de la petición a través de todos los microservicios en un único dashboard (Kibana/Grafana).

### 6.5. Historial Consultable
El **Transaction Service** proveerá endpoints de tipo `GET /api/transactions/history` que devolverán listados paginados leyendo desde la base de datos PostgreSQL, e incluirán el link de Cloud Storage para que los analistas puedan descargar el CSV original cuando lo requieran.

### 6.6. Estrategia de Despliegue (Docker y Kubernetes)
*Nota para puntos extra según rúbrica.*
Para garantizar la portabilidad, escalabilidad y alta disponibilidad requerida por la demanda masiva de fin de mes:
- **Dockerización:** Cada microservicio (Auth, Transaction, Approval, Notification) será empaquetado en su propia imagen Docker, utilizando construcciones multi-etapa (multi-stage builds) para mantener las imágenes livianas y seguras.
- **Kubernetes (K8s):** El ecosistema completo se desplegará en un clúster de Kubernetes.
  - Se utilizarán **Deployments** y **ReplicaSets** para escalar horizontalmente (HPA - Horizontal Pod Autoscaler) los servicios que más lo necesiten (por ejemplo, el *Transaction Service* puede escalar a 10 réplicas durante el pago de planillas, mientras que el *Auth Service* se mantiene en 3).
  - El API Gateway se implementará usando un **Ingress Controller** nativo de Kubernetes.
  - La comunicación interna utilizará los DNS internos de Kubernetes (servicios tipo `ClusterIP`), evitando exponer los microservicios directamente a Internet.
