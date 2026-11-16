import { Router } from "express";
import {
  daftarBarang, detailBarang, hapusBarang, kirimFotoBarang, simpanBarang,
} from "../controllers/barang.controller";
import { perluLogin, perluRole } from "../middleware/akses.middleware";
import { terimaFoto } from "../middleware/upload.middleware";

export const barangRouter = Router();
barangRouter.use(perluLogin, perluRole("pemilik", "pegawai"));

barangRouter.get("/", daftarBarang);
barangRouter.get("/:id", detailBarang);
barangRouter.get("/:id/foto", kirimFotoBarang);

const khususPemilik = perluRole("pemilik");
barangRouter.post("/", khususPemilik, terimaFoto, simpanBarang);
barangRouter.patch("/:id", khususPemilik, terimaFoto, simpanBarang);
barangRouter.delete("/:id", khususPemilik, hapusBarang);
