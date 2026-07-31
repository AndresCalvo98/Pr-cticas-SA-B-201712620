import type { RequestStatus } from "../models/operational-request";

export interface UpdateOperationalRequestStatusDto {
  estado: RequestStatus;
}
