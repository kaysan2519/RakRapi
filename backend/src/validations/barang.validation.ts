import { KesalahanKatalog } from "../middleware/error.middleware";
import { bilanganBulat, namaValid } from "./umum.validation";

export function kolomForm(body: unknown): Record<string, unknown> {
  const isian = body ?? {};
  if (typeof isian !== "object" || Array.isArray(isian)) {
    throw new KesalahanKatalog(400, "Kolom barang tidak dikenal.");
  }

  const kolomDiizinkan = ["nama", "kategori_id", "harga_rupiah", "stok", "satuan"];
  const adaKolomAsing = Object.keys(isian).some(kolom => !kolomDiizinkan.includes(kolom));
  if (adaKolomAsing) {
    throw new KesalahanKatalog(400, "Kolom barang tidak dikenal.");
  }

  return isian as Record<string, unknown>;
}

export function validasiBarang(input: Record<string, unknown>) {
  const satuan = input.satuan;
  const stokMasukan = input.stok;

  // Samakan pemisah desimal dari formulir dan JSON sebelum memeriksa format.
  let stok = "";
  if (typeof stokMasukan === "number" || typeof stokMasukan === "string") {
    stok = String(stokMasukan).replace(",", ".");
  }

  const nama = namaValid(input.nama, 150);
  const kategori_id = bilanganBulat(input.kategori_id, 1, "Kategori");
  const harga_rupiah = bilanganBulat(input.harga_rupiah, 0, "Harga rupiah");

  if (satuan !== "botol" && satuan !== "kg") {
    throw new KesalahanKatalog(400, "Pilih satuan botol atau kg.");
  }

  // Terima 1–9 digit sebelum titik dan, jika ada pecahan, 1–3 digit setelahnya.
  const polaStok = /^\d{1,9}(\.\d{1,3})?$/;
  if (!polaStok.test(stok)) {
    throw new KesalahanKatalog(400, "Stok harus nol atau lebih, maksimal tiga angka pecahan.");
  }

  if (satuan === "botol") {
    const jumlahBotol = Number(stok);
    if (!Number.isInteger(jumlahBotol)) {
      throw new KesalahanKatalog(400, "Jumlah botol harus bulat.");
    }
  }

  return { nama, kategori_id, harga_rupiah, satuan, stok };
}
