import type { RequestStatus } from "../models/operational-request";

export interface UpdateOperationalRequestDto {
  titulo: string;
  areaSolicitante: string;
  prioridad: number;
  costoEstimado: number;
  estado: RequestStatus;
}
