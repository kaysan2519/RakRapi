import type { PoolOptions } from "mysql2/promise";

// Susun opsi koneksi MySQL untuk Laragon (DB_SSL=false) maupun Aiven (DB_SSL=true).
export function opsiKoneksi(database = process.env.DB_NAME ?? "rakrapi"): PoolOptions {
  const host = (process.env.DB_HOST ?? "localhost").trim();
  const port = Number(process.env.DB_PORT ?? 3306);
  const sslAktif = (process.env.DB_SSL ?? "false").trim().toLowerCase() === "true";
  const caBase64 = (process.env.DB_SSL_CA_BASE64 ?? "").trim();

  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error("DB_PORT harus berupa nomor port yang valid.");
  }
  if (host.endsWith(".aivencloud.com") && !sslAktif) {
    throw new Error("Koneksi Aiven wajib menggunakan DB_SSL=true.");
  }

  const opsi: PoolOptions = {
    host,
    port,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database,
    connectTimeout: sslAktif ? 15000 : 3000,
  };

  if (sslAktif) {
    if (!caBase64) {
      throw new Error("Isi DB_SSL_CA_BASE64 saat DB_SSL=true.");
    }
    const ca = Buffer.from(caBase64, "base64");
    if (!ca.toString("utf8").includes("BEGIN CERTIFICATE")) {
      throw new Error("DB_SSL_CA_BASE64 bukan sertifikat CA yang valid.");
    }
    // Verifikasi sertifikat CA dan nama host (jangan dinonaktifkan).
    opsi.ssl = { ca, rejectUnauthorized: true, verifyIdentity: true };
  }

  return opsi;
}
