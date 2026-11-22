import { Router } from "express";
import {
  ajukanLamaran,
  daftarLamaranSaya,
  daftarLowongan,
  daftarSemuaLamaran,
  detailLowongan,
  hapusLowongan,
  kirimFotoLowongan,
  pinLowongan,
  simpanLowongan,
  tinjauLamaran,
  tutupLowongan,
} from "../controllers/lowongan.controller";
import { perluLogin, perluRole } from "../middleware/akses.middleware";
import { terimaFoto } from "../middleware/upload.middleware";

export const lowonganRouter = Router();
lowonganRouter.use(perluLogin);

// Rute lamaran ditempatkan sebelum /:id agar tidak terbaca sebagai ID lowongan.
lowonganRouter.get("/lamaran/saya", perluRole("warga"), daftarLamaranSaya);
lowonganRouter.get("/lamaran", perluRole("pemilik"), daftarSemuaLamaran);
lowonganRouter.patch("/lamaran/:id", perluRole("pemilik"), tinjauLamaran);

lowonganRouter.get("/", perluRole("pemilik", "pegawai", "warga"), daftarLowongan);
lowonganRouter.get("/:id", perluRole("pemilik", "pegawai", "warga"), detailLowongan);
lowonganRouter.get("/:id/foto", perluRole("pemilik", "pegawai", "warga"), kirimFotoLowongan);
lowonganRouter.post("/:id/lamar", perluRole("warga"), ajukanLamaran);

lowonganRouter.post("/", perluRole("pemilik"), terimaFoto, simpanLowongan);
lowonganRouter.patch("/:id", perluRole("pemilik"), terimaFoto, simpanLowongan);
lowonganRouter.patch("/:id/tutup", perluRole("pemilik"), tutupLowongan);
lowonganRouter.patch("/:id/pin", perluRole("pemilik"), pinLowongan);
lowonganRouter.delete("/:id", perluRole("pemilik"), hapusLowongan);
