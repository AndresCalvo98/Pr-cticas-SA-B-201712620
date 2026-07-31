CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS operational_requests (
  id SERIAL PRIMARY KEY,
  titulo TEXT NOT NULL,
  area_solicitante TEXT NOT NULL,
  prioridad INTEGER NOT NULL CHECK (prioridad BETWEEN 1 AND 5),
  costo_estimado NUMERIC(12, 2) NOT NULL CHECK (costo_estimado >= 0),
  estado TEXT NOT NULL CHECK (estado IN ('registrada', 'en_proceso', 'finalizada')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
