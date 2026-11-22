import { app } from "./app";
import { pulihkanFoto } from "./services/foto.service";

const port = Number(process.env.PORT ?? 3000);
const host = process.env.HOST?.trim() || "0.0.0.0";

app.listen(port, host, (error?: Error) => {
  if (error) {
    const kode = (error as NodeJS.ErrnoException).code;
    if (kode === "EADDRINUSE") {
      console.error(`Gagal menjalankan server: port ${port} sudah dipakai proses lain.`);
    } else {
      console.error(`Gagal menjalankan server: ${error.message}`);
    }
    process.exit(1);
  }
  const alamatTampil = host === "0.0.0.0" ? "127.0.0.1" : host;
  console.log(`RakRapi berjalan di http://${alamatTampil}:${port} (host: ${host})`);
  void pulihkanFoto().catch(() => console.warn("Pemulihan folder foto belum berhasil."));
});
