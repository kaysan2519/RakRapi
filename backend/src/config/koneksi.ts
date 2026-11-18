import { readFileSync } from "node:fs";
import type { PoolOptions } from "mysql2/promise";

// Dipakai oleh semua pool agar koneksi akun, katalog, dan health memakai TLS yang sama.
export function opsiKoneksi(
  user: string | undefined,
  password: string | undefined,
  database = process.env.DB_NAME ?? "rakrapi",
): PoolOptions {
  const mode = process.env.DB_MODE ?? "laragon";
  const host = process.env.DB_HOST ?? "127.0.0.1";
  const port = Number(process.env.DB_PORT ?? 3306);
  const lokasiCA = process.env.DB_SSL_CA;
  const memakaiAiven = mode === "aiven";

  if (mode !== "laragon" && mode !== "aiven") {
    throw new Error("DB_MODE harus laragon atau aiven.");
  }
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error("DB_PORT harus berupa nomor port yang valid.");
  }
  if (memakaiAiven && !host.endsWith(".aivencloud.com")) {
    throw new Error("Mode Aiven memerlukan DB_HOST dari layanan Aiven.");
  }
  if (host.endsWith(".aivencloud.com") && !memakaiAiven) {
    throw new Error("Gunakan DB_MODE=aiven untuk layanan Aiven.");
  }
  if (memakaiAiven && (!lokasiCA || !user || !password)) {
    throw new Error("Isi akun database dan DB_SSL_CA pada konfigurasi privat Aiven.");
  }

  const opsi: PoolOptions = {
    host,
    port,
    user,
    password,
    database,
    connectTimeout: memakaiAiven ? 15000 : 3000,
  };

  if (lokasiCA) {
    let ca: Buffer;
    try {
      ca = readFileSync(lokasiCA);
    } catch {
      throw new Error("File DB_SSL_CA tidak bisa dibaca.");
    }
    // Periksa penerbit sertifikat DAN nama host; jangan menonaktifkan verifikasi.
    opsi.ssl = { ca, rejectUnauthorized: true, verifyIdentity: true };
  }

  return opsi;
}
