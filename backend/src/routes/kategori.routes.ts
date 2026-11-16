import { Router } from "express";
import * as kategori from "../controllers/kategori.controller";
import { perluLogin, perluRole } from "../middleware/akses.middleware";

export const kategoriRouter = Router();
kategoriRouter.use(perluLogin, perluRole("pemilik"));

kategoriRouter.get("/", kategori.daftarKategori);
kategoriRouter.get("/:id", kategori.detailKategori);
kategoriRouter.post("/", kategori.tambahKategori);
kategoriRouter.patch("/:id", kategori.ubahKategori);
kategoriRouter.delete("/:id", kategori.hapusKategori);
