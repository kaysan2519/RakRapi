import { KesalahanKatalog } from "../middleware/error.middleware";
import { bilanganBulat } from "./umum.validation";

export function validasiPesanan(body: unknown) {
  if (!body || typeof body !== "object" || !("kunci_kirim" in body)
      || typeof body.kunci_kirim !== "string" || !/^[a-f0-9]{32}$/.test(body.kunci_kirim)) {
    throw new KesalahanKatalog(400, "Kunci pengiriman tidak valid.");
  }
  if (!("item" in body) || !Array.isArray(body.item) || !body.item.length) {
    throw new KesalahanKatalog(400, "Keranjang masih kosong.");
  }
  const ids = new Set<number>();
  const item = body.item.map((baris: unknown) => {
    if (!baris || typeof baris !== "object" || !("barang_id" in baris) || !("jumlah" in baris)) {
      throw new KesalahanKatalog(400, "Isi barang dan jumlah pesanan.");
    }
    const barang_id = bilanganBulat(baris.barang_id, 1, "ID barang");
    const nilai = baris.jumlah;
    const jumlah = typeof nilai === "string" || typeof nilai === "number" ? String(nilai).replace(",", ".") : "";
    // Format mengikuti stok katalog, tetapi jumlah pesanan wajib lebih dari nol.
    if (!/^\d{1,9}(\.\d{1,3})?$/.test(jumlah) || Number(jumlah) <= 0) {
      throw new KesalahanKatalog(400, "Jumlah harus lebih dari nol, maksimal tiga angka pecahan.");
    }
    if (ids.has(barang_id)) {
      throw new KesalahanKatalog(400, "Gabungkan jumlah untuk barang yang sama.");
    }
    ids.add(barang_id);
    return { barang_id, jumlah, satuan: "satuan" in baris ? baris.satuan : undefined };
  });
  return { kunci: body.kunci_kirim, item };
}
