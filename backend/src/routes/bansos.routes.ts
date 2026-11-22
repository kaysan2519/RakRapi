import { Router } from "express";
import {
  ajukanBansos,
  daftarBansos,
  daftarPengajuanSaya,
  daftarSemuaPengajuan,
  detailBansos,
  hapusBansos,
  kirimFotoBansos,
  pinBansos,
  simpanBansos,
  tinjauPengajuan,
} from "../controllers/bansos.controller";
import { perluLogin, perluRole } from "../middleware/akses.middleware";
import { terimaFoto } from "../middleware/upload.middleware";

export const bansosRouter = Router();
bansosRouter.use(perluLogin);

// Rute pengajuan ditempatkan sebelum /:id agar tidak terbaca sebagai ID program.
bansosRouter.get("/pengajuan/saya", perluRole("warga"), daftarPengajuanSaya);
bansosRouter.get("/pengajuan", perluRole("pemilik"), daftarSemuaPengajuan);
bansosRouter.patch("/pengajuan/:id", perluRole("pemilik"), tinjauPengajuan);

bansosRouter.get("/", perluRole("pemilik", "pegawai", "warga"), daftarBansos);
bansosRouter.get("/:id", perluRole("pemilik", "pegawai", "warga"), detailBansos);
bansosRouter.get("/:id/foto", perluRole("pemilik", "pegawai", "warga"), kirimFotoBansos);
bansosRouter.post("/:id/ajukan", perluRole("warga"), ajukanBansos);

bansosRouter.post("/", perluRole("pemilik"), terimaFoto, simpanBansos);
bansosRouter.patch("/:id", perluRole("pemilik"), terimaFoto, simpanBansos);
bansosRouter.patch("/:id/pin", perluRole("pemilik"), pinBansos);
bansosRouter.delete("/:id", perluRole("pemilik"), hapusBansos);
