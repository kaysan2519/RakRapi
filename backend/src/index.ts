import express, { type ErrorRequestHandler } from "express";
import { authRouter } from "./routes/auth";
import { healthRouter } from "./routes/health";

const app = express();
app.use("/api", healthRouter);
app.use("/api/auth", express.json({ limit: "8kb" }), authRouter);

const tanganiError: ErrorRequestHandler = (error, _req, res, _next) => {
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
