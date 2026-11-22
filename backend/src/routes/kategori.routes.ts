import { Router } from "express";
import * as kategori from "../controllers/kategori.controller";
import { perluLogin, perluRole } from "../middleware/akses.middleware";

export const kategoriRouter = Router();
kategoriRouter.use(perluLogin);

kategoriRouter.get("/", perluRole("pemilik", "pegawai", "warga"), kategori.daftarKategori);
kategoriRouter.use(perluRole("pemilik"));
kategoriRouter.get("/:id", kategori.detailKategori);
kategoriRouter.post("/", kategori.tambahKategori);
kategoriRouter.patch("/:id", kategori.ubahKategori);
kategoriRouter.delete("/:id", kategori.hapusKategori);
