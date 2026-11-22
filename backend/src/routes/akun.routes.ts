import { Router } from "express";
import {
  aksesPemilik,
  buatAkun,
  detailPegawai,
  listPegawai,
  login,
  nonaktifkanPegawai,
  profilSendiri,
} from "../controllers/akun.controller";
import { perluLogin, perluRole } from "../middleware/akses.middleware";

export const akunRouter = Router();

akunRouter.use((_req, res, next) => {
  res.set("Cache-Control", "no-store");
  next();
});

akunRouter.post("/register", buatAkun("warga"));
akunRouter.get("/pegawai", perluLogin, perluRole("pemilik"), listPegawai);
akunRouter.get("/pegawai/:id", perluLogin, perluRole("pemilik"), detailPegawai);
akunRouter.post("/pegawai", perluLogin, perluRole("pemilik"), buatAkun("pegawai"));
akunRouter.patch(
  "/pegawai/:id/berhentikan",
  perluLogin,
  perluRole("pemilik"),
  nonaktifkanPegawai,
);
akunRouter.post("/login", login);
akunRouter.get("/me", perluLogin, profilSendiri);
akunRouter.get("/pemilik", perluLogin, perluRole("pemilik"), aksesPemilik);
