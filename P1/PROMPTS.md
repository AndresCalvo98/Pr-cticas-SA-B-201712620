# Documentación de uso de IA

Este archivo registra el uso de IA de forma crítica y verificable. No se incluyeron respuestas decorativas ni texto genérico: cada prompt se usó para resolver una necesidad concreta del proyecto, y cada salida fue revisada manualmente antes de quedar en el código.

## Criterio general aplicado

La IA se utilizó como asistente de diseño y redacción técnica, no como autoridad final. El resultado se evaluó con tres preguntas:

1. ¿Respeta la estructura que pide la práctica?
2. ¿Es seguro para entradas y persistencia?
3. ¿Se puede explicar y mantener con criterio?

Si la respuesta era negativa, el resultado se refactorizaba o descartaba.

## Prompt 1 - Arquitectura base segura

**Prompt:**

Genera una API REST en TypeScript y Express para CRUD de solicitudes operativas con PostgreSQL. Quiero validación de entradas, consultas parametrizadas, manejo centralizado de errores y separación clara entre controller, service y repository.

**Respuesta obtenida:**

Se propuso una arquitectura por capas con controller, service y repository, además de modelos y DTOs para organizar el dominio.

**Ajustes aplicados:**

- Se agregó un tipo de error HTTP para controlar respuestas 400, 404 y 500.
- Se mantuvieron consultas SQL parametrizadas para evitar interpolación manual.
- Se separó el cambio de estado en un endpoint propio para respetar la intención REST.

**Valoración crítica:**

La respuesta fue útil como punto de partida, pero por sí sola no bastaba. Se ajustó el contrato del modelo para que coincidiera con la tabla real de Supabase y se evitó usar UUID cuando la base trabajaba con `SERIAL`.

## Prompt 2 - Validaciones de entrada

**Prompt:**

Diseña validaciones seguras para un DTO de creación de solicitudes operativas. Debe rechazar prioridades fuera de rango, costos negativos y estados inválidos.

**Respuesta obtenida:**

Se sugirieron validaciones básicas sobre strings y números, con una lista cerrada de estados permitidos.

**Ajustes aplicados:**

- Se normalizaron cadenas con `trim()` antes de persistir.
- Se centralizó la validación en el servicio, no en el controlador.
- Se exigió cuerpo no vacío para evitar errores de tipo en runtime.
- Se reforzó la validación del `id` para que solo acepte enteros válidos.

**Valoración crítica:**

El valor real no estuvo en validar por validar, sino en impedir que datos inválidos llegaran a la base o provocaran una caída del servidor. La validación quedó en la capa de negocio porque ahí es donde realmente se toma la decisión.

## Prompt 3 - Documentación SOLID para la rúbrica

**Prompt:**

Refactoriza la arquitectura para demostrar SOLID en una práctica académica. Necesito que cada principio se pueda explicar con evidencia real del código.

**Respuesta obtenida:**

Se recomendó dividir el sistema en controller, service, repository, interfaces y DTOs, y documentar el rol de cada capa.

**Ajustes aplicados:**

- Se documentó cada principio con archivos reales del proyecto.
- Se incluyeron fragmentos concretos de código en el README.
- Se añadió una guía de verificación para que la práctica pueda probarse sin ambigüedad.

**Valoración crítica:**

La respuesta fue correcta a nivel conceptual, pero había que convertirla en evidencia académica defendible. Por eso la documentación final no se limitó a definiciones: incluyó archivos, justificación y decisiones tomadas.

## Observaciones finales del uso de IA

- Ningún fragmento generado se tomó como definitivo sin revisión.
- Se corrigieron inconsistencias entre código y base de datos.
- Se priorizó seguridad, claridad y trazabilidad sobre rapidez de generación.
- El resultado final quedó alineado con la rúbrica de la práctica.
