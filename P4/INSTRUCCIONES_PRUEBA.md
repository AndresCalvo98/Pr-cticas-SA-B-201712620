# Manual de Pruebas y Ejecución - Práctica 4

Esta guía paso a paso te servirá para el día de la calificación. Sigue estas instrucciones al pie de la letra para levantar tu proyecto y demostrar que todos los microservicios y el API Gateway funcionan perfectamente.

---

## PASO 1: Levantar la Arquitectura (Docker Compose)

Antes de hacer cualquier prueba, necesitamos levantar los contenedores.
1. Abre Docker Desktop y asegúrate de que el motor de Docker esté corriendo (icono verde).
2. Abre una terminal en tu editor de código.
3. Navega hasta la carpeta de la Práctica 4:
   ```bash
   cd P4
   ```
4. Ejecuta el comando mágico para levantar toda la infraestructura:
   ```bash
   docker-compose up -d
   ```
5. *(Opcional)* Si te piden demostrar que los contenedores están arriba, ejecuta:
   ```bash
   docker ps
   ```
   > Deberías ver 5 contenedores corriendo: el `api-gateway` (en el puerto 8080) y los otros 4 microservicios internos.

---

## PASO 2: Importar el Contrato en Postman

El archivo `postman_collection.json` contiene todas las peticiones (REST y GraphQL) pre-configuradas para que no tengas que escribir nada a mano frente al auxiliar.

1. Abre la aplicación de **Postman**.
2. En la esquina superior izquierda, haz clic en el botón **"Import"** (Importar).
3. Selecciona la opción **"File"** (o arrastra el archivo) y busca en tu computadora el archivo `postman_collection.json` que está dentro de tu carpeta `P4`.
4. Haz clic en **"Import"**.
5. En el panel izquierdo de Postman, bajo la pestaña "Collections", aparecerá una nueva carpeta llamada **"API Contratos - Práctica 4"**.

---

## PASO 3: Demostrar que el sistema funciona

Ahora vas a ejecutar las peticiones en Postman para demostrarle al auxiliar que el API Gateway está enrutando todo correctamente. 

> **OJO:** Nota que todas las peticiones apuntan a `localhost:8080` (el API Gateway). Nunca le pegamos directamente a los puertos internos de los microservicios, lo cual demuestra que tu arquitectura está bien protegida.

### 1. Probar el Auth Service (REST)
- Ve a la carpeta `Auth Service` en Postman y abre la petición **"Authorize (REST)"**.
- Haz clic en el botón azul **"Send"**.
- **Lo que demuestra:** El Gateway recibe la petición en `/api/auth/authorize` y la redirige con éxito al contenedor en Node.js de la Práctica 2. Verás un JSON de respuesta con `"allowed": true` o `false`.

### 2. Probar el Transaction Service (GraphQL)
- Ve a la carpeta `Transaction Service` en Postman y abre la petición **"Get Batch Status (GraphQL)"**.
- Haz clic en **"Send"**.
- **Lo que demuestra:** Que implementaste un servidor **GraphQL en Go**. El Gateway enruta el tráfico de `/graphql/transactions` hacia el microservicio en Go, y este te devuelve la estructura que pediste. Verás en la respuesta: `{"data": {"batchStatus": "PENDING_CHECKER"}}`.

### 3. Probar el Approval Service (GraphQL)
- Ve a la carpeta `Approval Service` y abre **"Get Workflow (GraphQL)"**.
- Haz clic en **"Send"**.
- **Lo que demuestra:** Que cumpliste con el requisito de "GraphQL implementado en al menos 2 servicios", esta vez usando **Node.js**. Verás la respuesta estructurada: `{"data": {"getWorkflow": {"batchId": "batch-123", "status": "PENDING_CHECKER"}}}`.

### 4. Probar endpoints REST de carga y aprobación
- Puedes ejecutar **"Upload CSV (REST)"** y **"Approve Batch (REST)"** para demostrar que la funcionalidad base (subir lotes y aprobarlos) responde correctamente con códigos HTTP `200` o `201`.

---

## PASO 4: Apagar el sistema

Una vez que hayas terminado tu calificación y el auxiliar te haya puesto tus 100 puntos, es buena práctica apagar y limpiar tus contenedores para que no te consuman RAM.

1. En la misma terminal donde levantaste el proyecto (dentro de la carpeta `P4`), ejecuta:
   ```bash
   docker-compose down
   ```
2. Verás que Docker detiene y elimina los 5 contenedores limpiamente.
