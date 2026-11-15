import { eq } from "drizzle-orm";
import type { MySql2Database } from "drizzle-orm/mysql2";
import { catalogDb } from "../config/db";
import { barang, kategori } from "./tabel";
import { bilanganBulat, KesalahanKatalog, namaValid } from "./validasi";

export function barangDenganKategori(db: MySql2Database = catalogDb) {
  return db
    .select({
      id: barang.id,
      nama: barang.nama,
      kategori_id: kategori.id,
      nama_kategori: kategori.nama,
      harga_rupiah: barang.harga_rupiah,
      stok: barang.stok,
      satuan: barang.satuan,
    })
    .from(barang)
    .innerJoin(kategori, eq(barang.kategori_id, kategori.id));
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

export function sertakanUrlFoto<T extends { id: number }>(data: T) {
  return { ...data, foto_url: `/api/barang/${data.id}/foto` };
}
