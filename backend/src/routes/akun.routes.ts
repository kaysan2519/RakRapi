import { Router } from "express";
import { aksesPemilik, buatAkun, listPegawai, login, profilSendiri } from "../controllers/akun.controller";
import { perluLogin, perluRole } from "../middleware/akses.middleware";

export const akunRouter = Router();

akunRouter.use((_req, res, next) => {
  res.set("Cache-Control", "no-store");
  next();
});

akunRouter.post("/register", buatAkun("warga"));
akunRouter.get("/pegawai", perluLogin, perluRole("pemilik"), listPegawai);
akunRouter.post("/pegawai", perluLogin, perluRole("pemilik"), buatAkun("pegawai"));
akunRouter.post("/login", login);
akunRouter.get("/me", perluLogin, profilSendiri);
akunRouter.get("/pemilik", perluLogin, perluRole("pemilik"), aksesPemilik);
