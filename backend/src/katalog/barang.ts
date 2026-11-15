import { eq } from "drizzle-orm";
import { catalogDb } from "../config/db";
import { barang, kategori } from "./tabel";

export function barangDenganKategori() {
  return catalogDb.select({
    id: barang.id, nama: barang.nama, kategori_id: kategori.id, nama_kategori: kategori.nama,
    harga_rupiah: barang.harga_rupiah, stok: barang.stok, satuan: barang.satuan,
  }).from(barang).innerJoin(kategori, eq(barang.kategori_id, kategori.id));
}

export function sertakanUrlFoto<T extends { id: number }>(data: T) {
  return { ...data, foto_url: `/api/barang/${data.id}/foto` };
}
