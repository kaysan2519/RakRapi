import { app } from "./app";
import { pulihkanFoto } from "./services/foto.service";

const port = Number(process.env.PORT ?? 3000);
const host = process.env.HOST?.trim() || "127.0.0.1";
app.listen(port, host, () => {
  console.log(`RakRapi berjalan di http://${host}:${port}`);
  void pulihkanFoto().catch(() => console.warn("Pemulihan folder foto belum berhasil."));
});
