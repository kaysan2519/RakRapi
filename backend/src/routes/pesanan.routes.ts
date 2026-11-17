import { Router } from "express";
import { daftar, detail, kirim, konfirmasi } from "../controllers/pesanan.controller";
import { perluLogin, perluRole } from "../middleware/akses.middleware";

export const pesananRouter = Router();
pesananRouter.use(perluLogin);
pesananRouter.get("/", perluRole("warga", "pemilik", "pegawai"), daftar);
pesananRouter.get("/:id", perluRole("warga", "pemilik", "pegawai"), detail);
pesananRouter.post("/", perluRole("warga"), kirim);
pesananRouter.patch("/:id/konfirmasi", perluRole("pemilik","pegawai"), konfirmasi);
