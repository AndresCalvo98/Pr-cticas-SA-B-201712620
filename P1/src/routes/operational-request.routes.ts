import { Router } from "express";
import { asyncHandler } from "../utils/async-handler";
import type { OperationalRequestController } from "../controllers/operational-request.controller";

export const createOperationalRequestRouter = (
  controller: OperationalRequestController,
): Router => {
  const router = Router();

  router.get("/", asyncHandler(controller.getAll));
  router.post("/", asyncHandler(controller.create));
  router.put("/:id", asyncHandler(controller.update));
  router.patch("/:id/status", asyncHandler(controller.updateStatus));
  router.delete("/:id", asyncHandler(controller.delete));

  return router;
};
