import { and, asc, eq } from "drizzle-orm";
import type { MySql2Database } from "drizzle-orm/mysql2";
import { catalogDb } from "../config/db";
import { barang, kategori } from "../config/schema";
import { KesalahanKatalog } from "../middleware/error.middleware";
import { validasiBarang } from "../validations/barang.validation";
import { bacaFoto, denganKunciFoto, hapusJikaLepas, siapkanFoto, tulisFoto } from "./foto.service";

function barangDenganKategori(db: MySql2Database = catalogDb) {
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

export async function ambilDetailBarang(idBarang: number) {
  const [detail] = await barangDenganKategori().where(eq(barang.id, idBarang));
  if (!detail) {
    throw new KesalahanKatalog(404, "Barang tidak ditemukan.");
  }
  return sertakanUrlFoto(detail);
}

function sertakanUrlFoto<T extends { id: number }>(data: T) {
  return { ...data, foto_url: `/api/barang/${data.id}/foto` };
}

export async function ambilDaftarBarang() {
  const daftar = await barangDenganKategori().orderBy(asc(barang.nama), asc(barang.id));
  return daftar.map(sertakanUrlFoto);
}

export async function ambilFotoBarang(idBarang: number) {
  // Baca referensi dan file dalam satu kunci agar fotonya tidak berganti di tengah pembacaan.
  return denganKunciFoto(async db => {
    const dataBarang = await cariBarang(db, idBarang);
    return bacaFoto(dataBarang.foto_key);
  });
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
  return denganKunciFoto(async db => {
    const barangLama = idBarang ? await cariBarang(db, idBarang) : undefined;
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
        // Untuk barang baru, foto sudah diwajibkan sebelum validasi.
        const [hasil] = await db.insert(barang).values({ ...nilai, foto_key: fotoBaru!.key });
        idTersimpan = hasil.insertId;
      }
    } catch (err) {
      // Pastikan SQL benar-benar tidak merujuk file sebelum membuang file baru.
      if (fotoBaru) {
        await bersihkanFoto(db, fotoBaru.key);
      }
      throw err;
    }
    if (barangLama && fotoBaru) {
      await bersihkanFoto(db, barangLama.foto_key);
    }

    const [hasil] = await barangDenganKategori(db).where(eq(barang.id, idTersimpan));
    return sertakanUrlFoto(hasil);
  });
}

export async function hapusBarang(idBarang: number) {
  await denganKunciFoto(async db => {
    const lama = await cariBarang(db, idBarang);
    await db.delete(barang).where(eq(barang.id, idBarang));
    await bersihkanFoto(db, lama.foto_key);
  });
}

async function cariBarang(db: MySql2Database, id: number) {
  const [dataBarang] = await db.select().from(barang).where(eq(barang.id, id));
  if (!dataBarang) {
    throw new KesalahanKatalog(404, "Barang tidak ditemukan.");
  }

  return dataBarang;
}

async function bersihkanFoto(db: MySql2Database, key: string) {
  try {
    await hapusJikaLepas(db, key);
  } catch {
    console.warn("Pembersihan foto tertunda sampai pemulihan berikutnya.");
  }
}
