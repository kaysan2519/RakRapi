import express from "express";
import { tanganiError } from "./middleware/error.middleware";
import { akunRouter } from "./routes/akun.routes";
import { barangRouter } from "./routes/barang.routes";
import { healthRouter } from "./routes/health.routes";
import { kategoriRouter } from "./routes/kategori.routes";
import { lowonganRouter } from "./routes/lowongan.routes";
import { pesananRouter } from "./routes/pesanan.routes";

export const app = express();
app.use("/api/pesanan", express.json({ limit: "64kb" }), pesananRouter);
app.use("/api", healthRouter);
app.use("/api/auth", express.json({ limit: "8kb" }), akunRouter);
app.use("/api/kategori", express.json({ limit: "8kb" }), kategoriRouter);
app.use("/api/barang", express.json({ limit: "8kb" }), barangRouter);
app.use("/api/lowongan", express.json({ limit: "8kb" }), lowonganRouter);

app.use(tanganiError);
