import { app } from "./app";
import { pulihkanFoto } from "./services/foto.service";

const port = Number(process.env.PORT ?? 3000);
app.listen(port, "127.0.0.1", () => {
  console.log(`RakRapi berjalan di http://127.0.0.1:${port}`);
  void pulihkanFoto().catch(() => console.warn("Pemulihan folder foto belum berhasil."));
});
