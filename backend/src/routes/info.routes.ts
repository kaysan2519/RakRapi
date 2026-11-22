import { Router } from "express";
import { daftarPin, detailToko, ringkasanDashboard, ubahToko } from "../controllers/info.controller";
import { perluLogin, perluRole } from "../middleware/akses.middleware";

export const pinRouter = Router();
pinRouter.use(perluLogin);
pinRouter.get("/", perluRole("pemilik", "pegawai", "warga"), daftarPin);

export const tokoRouter = Router();
tokoRouter.use(perluLogin);
tokoRouter.get("/", perluRole("pemilik", "pegawai", "warga"), detailToko);
tokoRouter.patch("/", perluRole("pemilik"), ubahToko);

export const dashboardRouter = Router();
dashboardRouter.use(perluLogin);
dashboardRouter.get("/", perluRole("pemilik", "pegawai"), ringkasanDashboard);
