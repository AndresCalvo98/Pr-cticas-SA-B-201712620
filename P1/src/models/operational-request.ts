export type RequestStatus = "registrada" | "en_proceso" | "finalizada";

export interface OperationalRequest {
  id: number;
  titulo: string;
  areaSolicitante: string;
  prioridad: number;
  costoEstimado: number;
  estado: RequestStatus;
  createdAt: Date;
  updatedAt: Date;
}
