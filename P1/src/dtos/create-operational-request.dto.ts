import type { RequestStatus } from "../models/operational-request";

export interface CreateOperationalRequestDto {
  titulo: string;
  areaSolicitante: string;
  prioridad: number;
  costoEstimado: number;
  estado?: RequestStatus;
}
