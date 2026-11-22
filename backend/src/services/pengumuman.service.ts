import { and, desc, eq } from "drizzle-orm";
import { db } from "../config/db";
import { pengumuman } from "../config/schema";
import { KesalahanKatalog } from "../middleware/error.middleware";
import { booleanDariInput, namaValid, teksOpsional } from "../validations/umum.validation";
import { bacaFoto, bersihkanFotoAman, siapkanFoto, tulisFoto } from "./foto.service";

const jenisDiizinkan = ["Pengumuman", "Diskon", "Informasi toko"] as const;
type JenisPengumuman = (typeof jenisDiizinkan)[number];

function formatPengumuman<T extends { id: number; foto_key: string | null }>(row: T) {
  const { foto_key, ...sisa } = row;
  return {
    ...sisa,
    foto_url: foto_key ? `/api/pengumuman/${row.id}/foto` : null,
  };
}

export async function daftarPengumuman(termasukDitutup: boolean) {
  const filter = termasukDitutup ? undefined : eq(pengumuman.aktif, true);
  const rows = await db
    .select()
    .from(pengumuman)
    .where(filter)
    .orderBy(desc(pengumuman.is_pinned), desc(pengumuman.id));
  return rows.map(formatPengumuman);
}

export async function ambilDetailPengumuman(id: number, termasukDitutup: boolean) {
  const filter = termasukDitutup
    ? eq(pengumuman.id, id)
    : and(eq(pengumuman.id, id), eq(pengumuman.aktif, true));
  const [row] = await db.select().from(pengumuman).where(filter).limit(1);
  if (!row) {
    throw new KesalahanKatalog(404, "Pengumuman tidak ditemukan.");
  }
  return formatPengumuman(row);
}

export async function ambilFotoPengumuman(id: number) {
  const [row] = await db.select().from(pengumuman).where(eq(pengumuman.id, id)).limit(1);
  if (!row || !row.foto_key) {
    throw new KesalahanKatalog(404, "Foto pengumuman tidak ditemukan.");
  }
  return bacaFoto(row.foto_key);
}

export async function simpanPengumuman(
  id: number | undefined,
  isian: Record<string, unknown>,
  file: Express.Multer.File | undefined,
) {
  const lama = id
    ? (await db.select().from(pengumuman).where(eq(pengumuman.id, id)).limit(1))[0]
    : undefined;
  if (id && !lama) {
    throw new KesalahanKatalog(404, "Pengumuman tidak ditemukan.");
  }

  const judul = namaValid(isian.judul ?? lama?.judul, 150, "Judul pengumuman");
  const deskripsi = teksOpsional(isian.deskripsi ?? lama?.deskripsi ?? "", 1000, "Deskripsi pengumuman");
  const info_tambahan = teksOpsional(isian.info_tambahan ?? lama?.info_tambahan ?? "", 150, "Info tambahan");

  const jenisMentah = (isian.jenis ?? lama?.jenis ?? "Pengumuman") as string;
  if (!jenisDiizinkan.includes(jenisMentah as JenisPengumuman)) {
    throw new KesalahanKatalog(400, "Pilih jenis informasi: Pengumuman, Diskon, atau Informasi toko.");
  }
  const jenis = jenisMentah as JenisPengumuman;
  const aktif = booleanDariInput(isian.aktif, lama ? lama.aktif : true);
  const is_pinned = booleanDariInput(isian.is_pinned, lama ? lama.is_pinned : false);
  const hapusFoto = booleanDariInput(isian.hapus_foto, false);

  const fotoBaru = file ? await siapkanFoto(file) : undefined;
  let idTersimpan: number;

  try {
    if (fotoBaru) {
      await tulisFoto(fotoBaru);
    }
    if (id && lama) {
      const foto_key = fotoBaru ? fotoBaru.key : hapusFoto ? null : lama.foto_key;
      await db
        .update(pengumuman)
        .set({ judul, deskripsi, jenis, info_tambahan, aktif, is_pinned, foto_key })
        .where(eq(pengumuman.id, id));
      idTersimpan = id;
    } else {
      const [hasil] = await db.insert(pengumuman).values({
        judul,
        deskripsi,
        jenis,
        info_tambahan,
        aktif,
        is_pinned,
        foto_key: fotoBaru?.key ?? null,
      });
      idTersimpan = hasil.insertId;
    }
  } catch (err) {
    if (fotoBaru) {
      await bersihkanFotoAman(fotoBaru.key);
    }
    throw err;
  }

  if (lama?.foto_key && (fotoBaru || hapusFoto)) {
    await bersihkanFotoAman(lama.foto_key);
  }

  const [baru] = await db.select().from(pengumuman).where(eq(pengumuman.id, idTersimpan)).limit(1);
  return formatPengumuman(baru);
}

export async function ubahPinPengumuman(id: number, isPinned: boolean) {
  const [lama] = await db.select().from(pengumuman).where(eq(pengumuman.id, id)).limit(1);
  if (!lama) {
    throw new KesalahanKatalog(404, "Pengumuman tidak ditemukan.");
  }
  await db.update(pengumuman).set({ is_pinned: isPinned }).where(eq(pengumuman.id, id));
  return formatPengumuman({ ...lama, is_pinned: isPinned });
}

export async function hapusPengumuman(id: number) {
  const [lama] = await db.select().from(pengumuman).where(eq(pengumuman.id, id)).limit(1);
  if (!lama) {
    throw new KesalahanKatalog(404, "Pengumuman tidak ditemukan.");
  }
  await db.delete(pengumuman).where(eq(pengumuman.id, id));
  await bersihkanFotoAman(lama.foto_key);
}
