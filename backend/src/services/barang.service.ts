import { and, asc, eq, sql } from "drizzle-orm";
import { db } from "../config/db";
import { barang, kategori } from "../config/schema";
import { KesalahanKatalog } from "../middleware/error.middleware";
import { validasiBarang } from "../validations/barang.validation";
import { bacaFoto, bersihkanFotoAman, siapkanFoto, tulisFoto } from "./foto.service";

function barangDenganKategori() {
  return db
    .select({
      id: barang.id,
      nama: barang.nama,
      kategori_id: kategori.id,
      nama_kategori: kategori.nama,
      harga_rupiah: barang.harga_rupiah,
      stok: barang.stok,
      satuan: barang.satuan,
      deskripsi: barang.deskripsi,
    })
    .from(barang)
    .innerJoin(kategori, eq(barang.kategori_id, kategori.id));
}

function formatBarang<T extends { id: number; stok: string }>(data: T) {
  return {
    ...data,
    tersedia: Number(data.stok) > 0,
    foto_url: `/api/barang/${data.id}/foto`,
  };
}

export async function ambilDaftarBarang(filter?: { q?: string; kategoriId?: number }) {
  const kondisi = [];
  if (filter?.kategoriId !== undefined) {
    kondisi.push(eq(barang.kategori_id, filter.kategoriId));
  }
  if (filter?.q) {
    const pola = `%${filter.q.toLowerCase()}%`;
    kondisi.push(
      sql`(LOWER(${barang.nama}) LIKE ${pola} OR LOWER(${barang.deskripsi}) LIKE ${pola} OR LOWER(${kategori.nama}) LIKE ${pola})`,
    );
  }
  const query = barangDenganKategori();
  const daftar = await (kondisi.length > 0 ? query.where(and(...kondisi)) : query)
    .orderBy(asc(barang.nama), asc(barang.id));
  return daftar.map(formatBarang);
}

export async function ambilDetailBarang(idBarang: number) {
  const [detail] = await barangDenganKategori().where(eq(barang.id, idBarang));
  if (!detail) {
    throw new KesalahanKatalog(404, "Barang tidak ditemukan.");
  }
  return formatBarang(detail);
}

export async function ambilFotoBarang(idBarang: number) {
  const dataBarang = await cariBarang(idBarang);
  return bacaFoto(dataBarang.foto_key);
}

export async function simpanBarang(
  idBarang: number | undefined,
  isian: Record<string, unknown>,
  file: Express.Multer.File | undefined,
) {
  if (!idBarang && !file) {
    throw new KesalahanKatalog(400, "Foto barang wajib diunggah.");
  }
  if (idBarang && !file && Object.keys(isian).length === 0) {
    throw new KesalahanKatalog(400, "Pilih perubahan barang.");
  }

  const fotoBaru = file ? await siapkanFoto(file) : undefined;
  const barangLama = idBarang ? await cariBarang(idBarang) : undefined;
  const nilai = validasiBarang({ ...barangLama, ...isian });
  let idTersimpan: number;

  try {
    if (fotoBaru) {
      await tulisFoto(fotoBaru);
    }

    if (idBarang) {
      const perubahan: Partial<typeof barang.$inferInsert> = { ...nilai };
      if (fotoBaru) {
        perubahan.foto_key = fotoBaru.key;
      }
      // Edit harga/foto tidak boleh menimpa stok yang baru dikurangi oleh transaksi pesanan.
      if (isian.stok === undefined) delete perubahan.stok;
      const cekStokUntukSatuan = isian.satuan !== undefined && isian.stok === undefined;
      const [hasil] = await db.update(barang).set(perubahan).where(and(
        eq(barang.id, idBarang),
        cekStokUntukSatuan ? eq(barang.stok, barangLama!.stok) : undefined,
      ));
      if (!hasil.affectedRows) {
        throw new KesalahanKatalog(409, "Stok berubah. Muat ulang barang sebelum mengubah satuan.");
      }
      idTersimpan = idBarang;
    } else {
      const [hasil] = await db.insert(barang).values({ ...nilai, foto_key: fotoBaru!.key });
      idTersimpan = hasil.insertId;
    }
  } catch (err) {
    if (fotoBaru) {
      await bersihkanFotoAman(fotoBaru.key);
    }
    throw err;
  }

  if (barangLama && fotoBaru) {
    await bersihkanFotoAman(barangLama.foto_key);
  }

  const [hasil] = await barangDenganKategori().where(eq(barang.id, idTersimpan));
  return formatBarang(hasil);
}

export async function hapusBarang(idBarang: number) {
  const lama = await cariBarang(idBarang);
  await db.delete(barang).where(eq(barang.id, idBarang));
  await bersihkanFotoAman(lama.foto_key);
}

async function cariBarang(id: number) {
  const [dataBarang] = await db.select().from(barang).where(eq(barang.id, id));
  if (!dataBarang) {
    throw new KesalahanKatalog(404, "Barang tidak ditemukan.");
  }
  return dataBarang;
}
