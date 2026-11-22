import { and, asc, desc, eq, sql } from "drizzle-orm";
import { db } from "../config/db";
import { barang, detailPesanan, pesanan } from "../config/schema";
import { KesalahanKatalog } from "../middleware/error.middleware";
import type { validasiPesanan } from "../validations/pesanan.validation";

const ringkasan = {
  id: pesanan.id, nama_pemesan: pesanan.nama_pemesan, status: pesanan.status,
  dibuat: pesanan.dibuat, total_rupiah: pesanan.total_rupiah,
};

function subtotal(harga: number, jumlah: string) {
  const [bulat, pecahan = ""] = jumlah.split(".");
  const perseribu = BigInt(bulat + pecahan.padEnd(3, "0"));
  // Bulatkan sekali per baris ke rupiah terdekat, termasuk untuk pecahan kg.
  return (BigInt(harga) * perseribu + 500n) / 1000n;
}

export async function buatPesanan(warga: { id: number; nama: string }, input: ReturnType<typeof validasiPesanan>) {
  const filter = and(eq(pesanan.warga_id, warga.id), eq(pesanan.kunci_kirim, input.kunci));
  // Kunci unik juga menangani dua kiriman yang datang bersamaan.
  const cariKiriman = async () => (await db.select(ringkasan).from(pesanan).where(filter))[0];
  const sudahAda = await cariKiriman();
  if (sudahAda) return sudahAda;
  try {
    return await db.transaction(async tx => {
      let total = 0n;
      const rincian = [];
      // Urutan ID yang sama mencegah dua pesanan mengunci barang dalam urutan terbalik.
      for (const baris of input.item.sort((a, b) => a.barang_id - b.barang_id)) {
        const [b] = await tx.select().from(barang).where(eq(barang.id, baris.barang_id)).for("share");
        if (!b) throw new KesalahanKatalog(409, "Barang tidak tersedia lagi. Periksa keranjang.");
        if (baris.satuan !== undefined && baris.satuan !== b.satuan) {
          throw new KesalahanKatalog(409, `Satuan ${b.nama} berubah. Tambahkan kembali dari katalog.`);
        }
        if (b.satuan === "botol" && !Number.isInteger(Number(baris.jumlah))) {
          throw new KesalahanKatalog(400, `Jumlah ${b.nama} harus bulat untuk satuan botol.`);
        }
        total += subtotal(b.harga_rupiah, baris.jumlah);
        rincian.push({ barang_id: b.id, nama_barang: b.nama, satuan: b.satuan, jumlah: baris.jumlah, harga_rupiah: b.harga_rupiah });
      }
      const [hasil] = await tx.insert(pesanan).values({
        warga_id: warga.id, nama_pemesan: warga.nama, kunci_kirim: input.kunci, total_rupiah: total.toString(),
      });
      await tx.insert(detailPesanan).values(rincian.map(r => ({ ...r, pesanan_id: hasil.insertId })));
      const [baru] = await tx.select(ringkasan).from(pesanan).where(eq(pesanan.id, hasil.insertId));
      return baru;
    });
  } catch (error) {
    const kiriman = await cariKiriman();
    if (kiriman) return kiriman;
    throw error;
  }
}

export function daftarPesanan(wargaId?: number) {
  const filter = wargaId === undefined ? undefined : eq(pesanan.warga_id, wargaId);
  return db.select(ringkasan).from(pesanan).where(filter).orderBy(desc(pesanan.id));
}

export async function ambilPesanan(id: number, wargaId?: number) {
  const filter = and(eq(pesanan.id, id), wargaId === undefined ? undefined : eq(pesanan.warga_id, wargaId));
  const [data] = await db.select(ringkasan).from(pesanan).where(filter);
  if (!data) throw new KesalahanKatalog(404, "Pesanan tidak ditemukan.");
  const rincian = await db.select().from(detailPesanan).where(eq(detailPesanan.pesanan_id,id)).orderBy(asc(detailPesanan.id));
  return { ...data, item: rincian.map(r => ({ ...r, subtotal_rupiah: subtotal(r.harga_rupiah, r.jumlah).toString() })) };
}

export async function konfirmasiPesanan(id: number) {
  await db.transaction(async tx => {
    const [data] = await tx.select().from(pesanan).where(eq(pesanan.id, id)).for("update");
    if (!data) {
      throw new KesalahanKatalog(404, "Pesanan tidak ditemukan.");
    }
    // Petugas kedua menunggu kunci, lalu membaca status yang sudah dikonfirmasi.
    if (data.status === "Dikonfirmasi") return;
    const rincian = await tx.select().from(detailPesanan).where(eq(detailPesanan.pesanan_id,id)).orderBy(asc(detailPesanan.barang_id));
    for (const r of rincian) {
      if (r.barang_id === null) {
        throw new KesalahanKatalog(409, `${r.nama_barang} sudah dihapus dari katalog.`);
      }
      const [b] = await tx.select().from(barang).where(eq(barang.id,r.barang_id)).for("update");
      if (!b || b.satuan !== r.satuan) {
        throw new KesalahanKatalog(409, `${r.nama_barang} sudah dihapus atau satuannya berubah.`);
      }
      if (Number(b.stok) < Number(r.jumlah)) {
        throw new KesalahanKatalog(409, `Stok ${b.nama} tidak cukup.`);
      }
      // Jika item berikutnya gagal, MySQL membatalkan semua pengurangan pada transaksi ini.
      await tx.update(barang).set({ stok: sql`${barang.stok} - ${r.jumlah}` }).where(eq(barang.id,b.id));
    }
    await tx.update(pesanan).set({ status: "Dikonfirmasi" }).where(eq(pesanan.id,id));
  });
  return ambilPesanan(id);
}
