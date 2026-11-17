import { Router } from "express";
import { bukaLowongan, daftarLowongan, tutupLowongan } from "../controllers/lowongan.controller";
import { perluLogin, perluRole } from "../middleware/akses.middleware";

export const lowonganRouter = Router();
lowonganRouter.use(perluLogin);
lowonganRouter.get("/", perluRole("pemilik", "warga"), daftarLowongan);
lowonganRouter.post("/", perluRole("pemilik"), bukaLowongan);
lowonganRouter.patch("/:id/tutup", perluRole("pemilik"), tutupLowongan);
