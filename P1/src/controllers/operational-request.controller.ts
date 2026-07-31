import type { Request, Response } from "express";
import { HttpError } from "../utils/http-error";
import type { OperationalRequestService } from "../services/operational-request.service";

export class OperationalRequestController {
  constructor(private readonly service: OperationalRequestService) {}

  private getParamId(request: Request): string {
    const id = request.params.id;

    if (!id || Array.isArray(id)) {
      throw new HttpError(400, "El parámetro id es inválido");
    }

    return id;
  }

  getAll = async (_request: Request, response: Response): Promise<void> => {
    const requests = await this.service.getAll();
    response.json({ data: requests });
  };

  create = async (request: Request, response: Response): Promise<void> => {
    const requestCreated = await this.service.create(request.body);
    response.status(201).json({ data: requestCreated });
  };

  update = async (request: Request, response: Response): Promise<void> => {
    const updatedRequest = await this.service.update(this.getParamId(request), request.body);
    response.json({ data: updatedRequest });
  };

  updateStatus = async (request: Request, response: Response): Promise<void> => {
    const updatedRequest = await this.service.updateStatus(this.getParamId(request), request.body);
    response.json({ data: updatedRequest });
  };

  delete = async (request: Request, response: Response): Promise<void> => {
    await this.service.delete(this.getParamId(request));
    response.status(204).send();
  };
}
