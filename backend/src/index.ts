import express from "express";
import { healthRouter } from "./routes/health";

const app = express();
app.use("/api", healthRouter);

const port = Number(process.env.PORT ?? 3000);
app.listen(port, "127.0.0.1", () => {
  console.log(`RakRapi berjalan di http://127.0.0.1:${port}`);
});
