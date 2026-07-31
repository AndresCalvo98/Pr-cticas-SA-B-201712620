# Verificación final de la práctica

## 1. Compilación

- Ejecutar `npm run build`.
- Resultado esperado: compilación sin errores.

## 2. Arranque

- Ejecutar `npm run dev`.
- Resultado esperado: mensaje `Servidor escuchando en el puerto 3000`.

## 3. Pruebas de endpoints

Base URL: `http://localhost:3000/api/solicitudes`

### GET /api/solicitudes

- Esperado: `200 OK`.
- Resultado: lista de solicitudes.

### POST /api/solicitudes

Body:

```json
{
  "titulo": "Adquisición de nuevo servidor",
  "areaSolicitante": "Infraestructura TI",
  "prioridad": 3,
  "costoEstimado": 2500,
  "estado": "registrada"
}
```

- Esperado: `201 Created`.
- Resultado: objeto creado con `id` numérico.

### PUT /api/solicitudes/:id

Body:

```json
{
  "titulo": "Actualización total",
  "areaSolicitante": "Soporte",
  "prioridad": 4,
  "costoEstimado": 3500,
  "estado": "en_proceso"
}
```

- Esperado: `200 OK`.

### PATCH /api/solicitudes/:id/status

Body:

```json
{
  "estado": "finalizada"
}
```

- Esperado: `200 OK`.
- Resultado: solo cambia el estado.

### DELETE /api/solicitudes/:id

- Esperado: `204 No Content`.

## 4. Casos negativos

- Prioridad fuera de rango: `400 Bad Request`.
- Costo negativo: `400 Bad Request`.
- Estado inválido: `400 Bad Request`.
- Id no numérico: `400 Bad Request`.
- Id inexistente: `404 Not Found`.

## 5. Evidencia en Supabase

- Confirmar en la tabla `operational_requests` que los cambios de POST, PUT, PATCH y DELETE se reflejan.
- Verificar que `created_at` y `updated_at` se llenan correctamente.