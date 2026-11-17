import { Router } from "express";
import {
  daftarBarang, detailBarang, hapusBarang, kirimFotoBarang, simpanBarang,
} from "../controllers/barang.controller";
import { perluLogin, perluRole } from "../middleware/akses.middleware";
import { terimaFoto } from "../middleware/upload.middleware";

export const barangRouter = Router();
barangRouter.use(perluLogin, perluRole("pemilik", "pegawai", "warga"));

barangRouter.get("/", daftarBarang);
barangRouter.get("/:id", detailBarang);
barangRouter.get("/:id/foto", kirimFotoBarang);

const pengelolaBarang = perluRole("pemilik", "pegawai");
barangRouter.post("/", pengelolaBarang, terimaFoto, simpanBarang);
barangRouter.patch("/:id", pengelolaBarang, terimaFoto, simpanBarang);
barangRouter.delete("/:id", perluRole("pemilik"), hapusBarang);
