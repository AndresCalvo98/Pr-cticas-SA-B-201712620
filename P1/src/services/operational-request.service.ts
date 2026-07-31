import { HttpError } from "../utils/http-error";
import type { CreateOperationalRequestDto } from "../dtos/create-operational-request.dto";
import type { UpdateOperationalRequestDto } from "../dtos/update-operational-request.dto";
import type { UpdateOperationalRequestStatusDto } from "../dtos/update-operational-request-status.dto";
import type { OperationalRequestRepository } from "../interfaces/operational-request-repository";
import type { OperationalRequest } from "../models/operational-request";

const allowedStatuses = new Set(["registrada", "en_proceso", "finalizada"] as const);

export class OperationalRequestService {
  constructor(private readonly repository: OperationalRequestRepository) {}

  getAll(): Promise<OperationalRequest[]> {
    return this.repository.findAll();
  }

  async create(dto: CreateOperationalRequestDto): Promise<OperationalRequest> {
    this.assertBody(dto);
    this.validateText(dto.titulo, "titulo");
    this.validateText(dto.areaSolicitante, "areaSolicitante");
    this.validatePriority(dto.prioridad);
    this.validateMoney(dto.costoEstimado);

    const estado = this.validateStatus(dto.estado ?? "registrada");

    return this.repository.create({
      titulo: dto.titulo.trim(),
      areaSolicitante: dto.areaSolicitante.trim(),
      prioridad: dto.prioridad,
      costoEstimado: dto.costoEstimado,
      estado,
    });
  }

  async update(id: string, dto: UpdateOperationalRequestDto): Promise<OperationalRequest> {
    this.validateId(id);
    this.assertBody(dto);
    this.validateText(dto.titulo, "titulo");
    this.validateText(dto.areaSolicitante, "areaSolicitante");
    this.validatePriority(dto.prioridad);
    this.validateMoney(dto.costoEstimado);
    const estado = this.validateStatus(dto.estado);

    const updated = await this.repository.update(id, {
      titulo: dto.titulo.trim(),
      areaSolicitante: dto.areaSolicitante.trim(),
      prioridad: dto.prioridad,
      costoEstimado: dto.costoEstimado,
      estado,
    });

    if (!updated) {
      throw new HttpError(404, "Solicitud operativa no encontrada");
    }

    return updated;
  }

  async updateStatus(id: string, dto: UpdateOperationalRequestStatusDto): Promise<OperationalRequest> {
    this.validateId(id);
    this.assertBody(dto);
    const estado = this.validateStatus(dto.estado);

    const updated = await this.repository.updateStatus(id, estado);

    if (!updated) {
      throw new HttpError(404, "Solicitud operativa no encontrada");
    }

    return updated;
  }

  async delete(id: string): Promise<void> {
    this.validateId(id);

    const deleted = await this.repository.delete(id);

    if (!deleted) {
      throw new HttpError(404, "Solicitud operativa no encontrada");
    }
  }

  private validateId(id: string): void {
    if (!id || !/^\d+$/.test(id)) {
      throw new HttpError(400, "El id debe ser un entero válido");
    }
  }

  private assertBody(dto: unknown): asserts dto is Record<string, unknown> {
    if (!dto || typeof dto !== "object" || Array.isArray(dto)) {
      throw new HttpError(400, "El cuerpo de la solicitud es obligatorio");
    }
  }

  private validateText(value: string, fieldName: string): void {
    if (!value || value.trim().length < 3) {
      throw new HttpError(400, `El campo ${fieldName} debe tener al menos 3 caracteres`);
    }
  }

  private validatePriority(priority: number): void {
    if (!Number.isInteger(priority) || priority < 1 || priority > 5) {
      throw new HttpError(400, "La prioridad debe ser un entero entre 1 y 5");
    }
  }

  private validateMoney(value: number): void {
    if (!Number.isFinite(value) || value < 0) {
      throw new HttpError(400, "El costo estimado debe ser un número mayor o igual a 0");
    }
  }

  private validateStatus(status: string) {
    if (!allowedStatuses.has(status as (typeof allowedStatuses extends Set<infer T> ? T : never))) {
      throw new HttpError(400, "El estado debe ser registrada, en_proceso o finalizada");
    }

    return status as "registrada" | "en_proceso" | "finalizada";
  }
}
