import express, { type ErrorRequestHandler } from "express";
import { authRouter } from "./routes/auth";
import { healthRouter } from "./routes/health";
import { kategoriRouter } from "./routes/kategori";
import { KesalahanKatalog, kodeMysql } from "./katalog/validasi";

const app = express();
app.use("/api", healthRouter);
app.use("/api/auth", express.json({ limit: "8kb" }), authRouter);
app.use("/api/kategori", express.json({ limit: "8kb" }), kategoriRouter);

const tanganiError: ErrorRequestHandler = (error, _req, res, _next) => {
  if (error instanceof KesalahanKatalog) {
    res.status(error.status).json({ pesan: error.message });
    return;
  }
  switch (kodeMysql(error)) {
    case "ER_DUP_ENTRY":
      res.status(409).json({ pesan: "Nama kategori sudah digunakan." });
      return;
    case "ER_ROW_IS_REFERENCED_2":
      res.status(409).json({ pesan: "Kategori ini masih digunakan. Kategori bisa dihapus setelah tidak ada barang yang menggunakannya." });
      return;
    case "ER_NO_REFERENCED_ROW_2":
      res.status(400).json({ pesan: "Kategori tidak ditemukan." });
      return;
  }
  if (error.type === "entity.parse.failed" || error.status === 413) {
    res.status(error.status === 413 ? 413 : 400).json({ pesan: "Isi permintaan tidak valid." });
    return;
  }
  res.status(503).json({ pesan: "Layanan belum tersedia." });
};
app.use(tanganiError);

const port = Number(process.env.PORT ?? 3000);
app.listen(port, "127.0.0.1", () => {
  console.log(`RakRapi berjalan di http://127.0.0.1:${port}`);
});
