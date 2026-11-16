import { Router } from "express";
import { periksaHealth } from "../controllers/health.controller";

export const healthRouter = Router();
healthRouter.get("/health", periksaHealth);
