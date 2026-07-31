import type {
  OperationalRequest,
  RequestStatus,
} from "../models/operational-request";

export interface OperationalRequestRepository {
  findAll(): Promise<OperationalRequest[]>;
  findById(id: string): Promise<OperationalRequest | null>;
  create(input: {
    titulo: string;
    areaSolicitante: string;
    prioridad: number;
    costoEstimado: number;
    estado: RequestStatus;
  }): Promise<OperationalRequest>;
  update(
    id: string,
    input: {
      titulo: string;
      areaSolicitante: string;
      prioridad: number;
      costoEstimado: number;
      estado: RequestStatus;
    },
  ): Promise<OperationalRequest | null>;
  updateStatus(id: string, estado: RequestStatus): Promise<OperationalRequest | null>;
  delete(id: string): Promise<boolean>;
}
