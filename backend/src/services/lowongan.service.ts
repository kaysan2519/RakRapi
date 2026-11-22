import { and, desc, eq } from "drizzle-orm";
import { db } from "../config/db";
import { lamaran, lowongan, users } from "../config/schema";
import { KesalahanKatalog, kodeMysql } from "../middleware/error.middleware";
import { booleanDariInput, namaValid, teksOpsional } from "../validations/umum.validation";
import { bacaFoto, bersihkanFotoAman, siapkanFoto, tulisFoto } from "./foto.service";

function formatLowongan<T extends { id: number; foto_key: string | null }>(row: T) {
  const { foto_key, ...sisa } = row;
  return {
    ...sisa,
    foto_url: foto_key ? `/api/lowongan/${row.id}/foto` : null,
  };
}

export async function daftarLowongan(termasukDitutup: boolean) {
  const filter = termasukDitutup ? undefined : eq(lowongan.aktif, true);
  const rows = await db
    .select()
    .from(lowongan)
    .where(filter)
    .orderBy(desc(lowongan.is_pinned), desc(lowongan.id));
  return rows.map(formatLowongan);
}

export async function ambilDetailLowongan(id: number, termasukDitutup: boolean) {
  const filter = termasukDitutup
    ? eq(lowongan.id, id)
    : and(eq(lowongan.id, id), eq(lowongan.aktif, true));
  const [row] = await db.select().from(lowongan).where(filter).limit(1);
  if (!row) {
    throw new KesalahanKatalog(404, "Lowongan tidak ditemukan.");
  }
  return formatLowongan(row);
}

export async function ambilFotoLowongan(id: number) {
  const [row] = await db.select().from(lowongan).where(eq(lowongan.id, id)).limit(1);
  if (!row || !row.foto_key) {
    throw new KesalahanKatalog(404, "Foto lowongan tidak ditemukan.");
  }
  return bacaFoto(row.foto_key);
}

export async function simpanLowongan(
  id: number | undefined,
  isian: Record<string, unknown>,
  file: Express.Multer.File | undefined,
) {
  const lama = id
    ? (await db.select().from(lowongan).where(eq(lowongan.id, id)).limit(1))[0]
    : undefined;
  if (id && !lama) {
    throw new KesalahanKatalog(404, "Lowongan tidak ditemukan.");
  }

  const judul = namaValid(isian.judul ?? lama?.judul, 150, "Judul lowongan");
  const deskripsi = teksOpsional(isian.deskripsi ?? lama?.deskripsi ?? "", 1000, "Deskripsi lowongan");
  const persyaratan = teksOpsional(isian.persyaratan ?? lama?.persyaratan ?? "", 1000, "Persyaratan");
  const lokasi = teksOpsional(isian.lokasi ?? lama?.lokasi ?? "Toko RakRapi", 150, "Lokasi") || "Toko RakRapi";
  const info_tambahan = teksOpsional(isian.info_tambahan ?? lama?.info_tambahan ?? "", 150, "Info tambahan");
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
        .update(lowongan)
        .set({ judul, deskripsi, persyaratan, lokasi, info_tambahan, aktif, is_pinned, foto_key })
        .where(eq(lowongan.id, id));
      idTersimpan = id;
    } else {
      const [hasil] = await db.insert(lowongan).values({
        judul,
        deskripsi,
        persyaratan,
        lokasi,
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

  const [baru] = await db.select().from(lowongan).where(eq(lowongan.id, idTersimpan)).limit(1);
  return formatLowongan(baru);
}

export async function tutupLowongan(id: number) {
  const [hasil] = await db
    .update(lowongan)
    .set({ aktif: false, is_pinned: false })
    .where(eq(lowongan.id, id));
  if (hasil.affectedRows === 0) {
    throw new KesalahanKatalog(404, "Lowongan tidak ditemukan.");
  }
}

export async function ubahPinLowongan(id: number, isPinned: boolean) {
  const [lama] = await db.select().from(lowongan).where(eq(lowongan.id, id)).limit(1);
  if (!lama) {
    throw new KesalahanKatalog(404, "Lowongan tidak ditemukan.");
  }
  await db.update(lowongan).set({ is_pinned: isPinned }).where(eq(lowongan.id, id));
  return formatLowongan({ ...lama, is_pinned: isPinned });
}

export async function hapusLowongan(id: number) {
  const [lama] = await db.select().from(lowongan).where(eq(lowongan.id, id)).limit(1);
  if (!lama) {
    throw new KesalahanKatalog(404, "Lowongan tidak ditemukan.");
  }
  await db.delete(lowongan).where(eq(lowongan.id, id));
  await bersihkanFotoAman(lama.foto_key);
}

export async function ajukanLamaran(
  lowonganId: number,
  warga: { id: number; nama: string },
  isian: Record<string, unknown>,
) {
  const nama_pelamar = namaValid(isian.nama_pelamar ?? warga.nama, 100, "Nama pelamar");
  const keterangan = namaValid(isian.keterangan, 1000, "Alasan atau keterangan");

  const [target] = await db.select().from(lowongan).where(eq(lowongan.id, lowonganId)).limit(1);
  if (!target) {
    throw new KesalahanKatalog(404, "Lowongan tidak ditemukan.");
  }
  if (!target.aktif) {
    throw new KesalahanKatalog(409, "Lowongan sudah ditutup dan tidak menerima lamaran.");
  }

  try {
    const [hasil] = await db.insert(lamaran).values({
      lowongan_id: lowonganId,
      warga_id: warga.id,
      nama_pelamar,
      keterangan,
      status: "Menunggu verifikasi",
    });
    const [baru] = await db.select().from(lamaran).where(eq(lamaran.id, hasil.insertId)).limit(1);
    return { ...baru, judul_lowongan: target.judul };
  } catch (err) {
    if (kodeMysql(err) === "ER_DUP_ENTRY") {
      throw new KesalahanKatalog(409, "Anda sudah mengajukan lamaran untuk lowongan ini.");
    }
    throw err;
  }
}

export async function daftarLamaran(wargaId?: number) {
  const query = db
    .select({
      id: lamaran.id,
      lowongan_id: lamaran.lowongan_id,
      judul_lowongan: lowongan.judul,
      warga_id: lamaran.warga_id,
      email_warga: users.email,
      nama_pelamar: lamaran.nama_pelamar,
      keterangan: lamaran.keterangan,
      status: lamaran.status,
      dibuat: lamaran.dibuat,
    })
    .from(lamaran)
    .innerJoin(lowongan, eq(lamaran.lowongan_id, lowongan.id))
    .innerJoin(users, eq(lamaran.warga_id, users.id));

  return (wargaId === undefined ? query : query.where(eq(lamaran.warga_id, wargaId)))
    .orderBy(desc(lamaran.id));
}

export async function tinjauLamaran(id: number, statusBaru: unknown) {
  if (statusBaru !== "Disetujui" && statusBaru !== "Ditolak") {
    throw new KesalahanKatalog(400, "Pilih status Disetujui atau Ditolak.");
  }
  const [lama] = await db.select().from(lamaran).where(eq(lamaran.id, id)).limit(1);
  if (!lama) {
    throw new KesalahanKatalog(404, "Lamaran tidak ditemukan.");
  }
  if (lama.status !== "Menunggu verifikasi") {
    throw new KesalahanKatalog(409, "Lamaran ini sudah diperiksa sebelumnya.");
  }
  await db.update(lamaran).set({ status: statusBaru }).where(eq(lamaran.id, id));
  const [baru] = await db
    .select({
      id: lamaran.id,
      lowongan_id: lamaran.lowongan_id,
      judul_lowongan: lowongan.judul,
      warga_id: lamaran.warga_id,
      nama_pelamar: lamaran.nama_pelamar,
      keterangan: lamaran.keterangan,
      status: lamaran.status,
      dibuat: lamaran.dibuat,
    })
    .from(lamaran)
    .innerJoin(lowongan, eq(lamaran.lowongan_id, lowongan.id))
    .where(eq(lamaran.id, id))
    .limit(1);
  return baru;
}
