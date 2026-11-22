import { Router } from "express";
import { bayar, daftar, detail, kirim, konfirmasi, selesai, siapDiambil } from "../controllers/pesanan.controller";
import { perluLogin, perluRole } from "../middleware/akses.middleware";

export const pesananRouter = Router();
pesananRouter.use(perluLogin);
pesananRouter.get("/", perluRole("warga", "pemilik", "pegawai"), daftar);
pesananRouter.get("/:id", perluRole("warga", "pemilik", "pegawai"), detail);
pesananRouter.post("/", perluRole("warga"), kirim);
pesananRouter.patch("/:id/konfirmasi", perluRole("pemilik", "pegawai"), konfirmasi);
pesananRouter.patch("/:id/siap", perluRole("pemilik", "pegawai"), siapDiambil);
pesananRouter.patch("/:id/bayar", perluRole("pemilik", "pegawai"), bayar);
pesananRouter.patch("/:id/selesai", perluRole("pemilik", "pegawai"), selesai);
