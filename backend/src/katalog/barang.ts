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
  const nama = namaValid(input.nama, 150);
  const kategori_id = bilanganBulat(input.kategori_id, 1, "Kategori");
  const harga_rupiah = bilanganBulat(input.harga_rupiah, 0, "Harga rupiah");
  const satuan = input.satuan;
  if (satuan !== "botol" && satuan !== "kg") throw new KesalahanKatalog(400, "Pilih satuan botol atau kg.");
  const stok = (typeof input.stok === "number" || typeof input.stok === "string") ? String(input.stok).replace(",", ".") : "";
  if (!/^\d{1,9}(\.\d{1,3})?$/.test(stok)) throw new KesalahanKatalog(400, "Stok harus nol atau lebih, maksimal tiga angka pecahan.");
  if (satuan === "botol" && Number(stok) % 1 !== 0) throw new KesalahanKatalog(400, "Jumlah botol harus bulat.");
  return { nama, kategori_id, harga_rupiah, satuan, stok };
}

export function sertakanUrlFoto<T extends { id: number }>(data: T) {
  return { ...data, foto_url: `/api/barang/${data.id}/foto` };
}
