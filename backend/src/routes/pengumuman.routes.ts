import { Router } from "express";
import {
  daftarPengumuman,
  detailPengumuman,
  hapusPengumuman,
  kirimFotoPengumuman,
  pinPengumuman,
  simpanPengumuman,
} from "../controllers/pengumuman.controller";
import { perluLogin, perluRole } from "../middleware/akses.middleware";
import { terimaFoto } from "../middleware/upload.middleware";

export const pengumumanRouter = Router();
pengumumanRouter.use(perluLogin);

pengumumanRouter.get("/", perluRole("pemilik", "pegawai", "warga"), daftarPengumuman);
pengumumanRouter.get("/:id", perluRole("pemilik", "pegawai", "warga"), detailPengumuman);
pengumumanRouter.get("/:id/foto", perluRole("pemilik", "pegawai", "warga"), kirimFotoPengumuman);

pengumumanRouter.post("/", perluRole("pemilik"), terimaFoto, simpanPengumuman);
pengumumanRouter.patch("/:id", perluRole("pemilik"), terimaFoto, simpanPengumuman);
pengumumanRouter.patch("/:id/pin", perluRole("pemilik"), pinPengumuman);
pengumumanRouter.delete("/:id", perluRole("pemilik"), hapusPengumuman);
