import { KesalahanKatalog } from "../middleware/error.middleware";
import { bilanganBulat, namaValid, teksOpsional } from "./umum.validation";

export const satuanDiizinkan = [
  "botol",
  "kg",
  "pcs",
  "bungkus",
  "pack",
  "sisir",
  "kotak",
  "lembar",
  "sachet",
] as const;

export function kolomForm(body: unknown): Record<string, unknown> {
  const isian = body ?? {};
  if (typeof isian !== "object" || Array.isArray(isian)) {
    throw new KesalahanKatalog(400, "Kolom barang tidak dikenal.");
  }

  const kolomDiizinkan = ["nama", "kategori_id", "harga_rupiah", "stok", "satuan", "deskripsi"];
  const adaKolomAsing = Object.keys(isian).some(kolom => !kolomDiizinkan.includes(kolom));
  if (adaKolomAsing) {
    throw new KesalahanKatalog(400, "Kolom barang tidak dikenal.");
  }

  return isian as Record<string, unknown>;
}

export function validasiBarang(input: Record<string, unknown>) {
  const satuan = typeof input.satuan === "string" ? input.satuan.trim().toLowerCase() : "";
  const stokMasukan = input.stok;

  // Samakan pemisah desimal dari formulir dan JSON sebelum memeriksa format.
  let stok = "";
  if (typeof stokMasukan === "number" || typeof stokMasukan === "string") {
    stok = String(stokMasukan).replace(",", ".");
  }

  const nama = namaValid(input.nama, 150, "Nama barang");
  const kategori_id = bilanganBulat(input.kategori_id, 1, "Kategori");
  const harga_rupiah = bilanganBulat(input.harga_rupiah, 1, "Harga rupiah");
  const deskripsi = teksOpsional(input.deskripsi, 500, "Deskripsi barang");

  if (!satuanDiizinkan.includes(satuan as (typeof satuanDiizinkan)[number])) {
    throw new KesalahanKatalog(
      400,
      `Pilih satuan yang valid (${satuanDiizinkan.join(", ")}).`,
    );
  }

  // Terima 1–9 digit sebelum titik dan, jika ada pecahan, 1–3 digit setelahnya.
  const polaStok = /^\d{1,9}(\.\d{1,3})?$/;
  if (!polaStok.test(stok)) {
    throw new KesalahanKatalog(400, "Stok harus nol atau lebih, maksimal tiga angka pecahan.");
  }

  // Hanya satuan kg yang mendukung stok pecahan; satuan hitungan wajib bilangan bulat.
  if (satuan !== "kg") {
    const jumlahBulat = Number(stok);
    if (!Number.isInteger(jumlahBulat)) {
      throw new KesalahanKatalog(400, `Jumlah stok untuk satuan ${satuan} harus bilangan bulat.`);
    }
  }

  return { nama, kategori_id, harga_rupiah, satuan, stok, deskripsi };
}
