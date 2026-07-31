import type { Pool } from "pg";
import type { OperationalRequestRepository } from "../interfaces/operational-request-repository";
import type {
  OperationalRequest,
  RequestStatus,
} from "../models/operational-request";

const mapRowToOperationalRequest = (row: any): OperationalRequest => ({
  id: Number(row.id),
  titulo: row.titulo,
  areaSolicitante: row.area_solicitante,
  prioridad: row.prioridad,
  costoEstimado: Number(row.costo_estimado),
  estado: row.estado,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export class PostgresOperationalRequestRepository
  implements OperationalRequestRepository
{
  constructor(private readonly pool: Pool) {}

  async findAll(): Promise<OperationalRequest[]> {
    const result = await this.pool.query(
      `SELECT id, titulo, area_solicitante, prioridad, costo_estimado, estado, created_at, updated_at
       FROM operational_requests
       ORDER BY created_at DESC`,
    );

    return result.rows.map(mapRowToOperationalRequest);
  }

  async findById(id: string): Promise<OperationalRequest | null> {
    const result = await this.pool.query(
      `SELECT id, titulo, area_solicitante, prioridad, costo_estimado, estado, created_at, updated_at
       FROM operational_requests
       WHERE id = $1`,
      [id],
    );

    return result.rows[0] ? mapRowToOperationalRequest(result.rows[0]) : null;
  }

  async create(input: {
    titulo: string;
    areaSolicitante: string;
    prioridad: number;
    costoEstimado: number;
    estado: RequestStatus;
  }): Promise<OperationalRequest> {
    const result = await this.pool.query(
      `INSERT INTO operational_requests (
         titulo, area_solicitante, prioridad, costo_estimado, estado
       ) VALUES ($1, $2, $3, $4, $5)
       RETURNING id, titulo, area_solicitante, prioridad, costo_estimado, estado, created_at, updated_at`,
      [
        input.titulo,
        input.areaSolicitante,
        input.prioridad,
        input.costoEstimado,
        input.estado,
      ],
    );

    return mapRowToOperationalRequest(result.rows[0]);
  }

  async update(
    id: string,
    input: {
      titulo: string;
      areaSolicitante: string;
      prioridad: number;
      costoEstimado: number;
      estado: RequestStatus;
    },
  ): Promise<OperationalRequest | null> {
    const result = await this.pool.query(
      `UPDATE operational_requests
       SET titulo = $2,
           area_solicitante = $3,
           prioridad = $4,
           costo_estimado = $5,
           estado = $6,
           updated_at = NOW()
       WHERE id = $1
       RETURNING id, titulo, area_solicitante, prioridad, costo_estimado, estado, created_at, updated_at`,
      [
        id,
        input.titulo,
        input.areaSolicitante,
        input.prioridad,
        input.costoEstimado,
        input.estado,
      ],
    );

    return result.rows[0] ? mapRowToOperationalRequest(result.rows[0]) : null;
  }

  async updateStatus(id: string, estado: RequestStatus): Promise<OperationalRequest | null> {
    const result = await this.pool.query(
      `UPDATE operational_requests
       SET estado = $2,
           updated_at = NOW()
       WHERE id = $1
       RETURNING id, titulo, area_solicitante, prioridad, costo_estimado, estado, created_at, updated_at`,
      [id, estado],
    );

    return result.rows[0] ? mapRowToOperationalRequest(result.rows[0]) : null;
  }

  async delete(id: string): Promise<boolean> {
    const result = await this.pool.query(
      "DELETE FROM operational_requests WHERE id = $1",
      [id],
    );

    return (result.rowCount ?? 0) > 0;
  }
}
