import { and, desc, eq, sql } from "drizzle-orm";
import { db } from "../config/db";
import { pengajuanBansos, programBansos, users } from "../config/schema";
import { KesalahanKatalog, kodeMysql } from "../middleware/error.middleware";
import { bilanganBulat, booleanDariInput, namaValid, teksOpsional } from "../validations/umum.validation";
import { bacaFoto, bersihkanFotoAman, siapkanFoto, tulisFoto } from "./foto.service";

function formatProgram(
  row: typeof programBansos.$inferSelect,
  terpakai: number,
) {
  const { foto_key, ...sisa } = row;
  return {
    ...sisa,
    terpakai,
    sisa_kuota: Math.max(0, row.kuota - terpakai),
    foto_url: foto_key ? `/api/bansos/${row.id}/foto` : null,
  };
}

async function hitungDisetujuiPerProgram(): Promise<Map<number, number>> {
  const rows = await db
    .select({
      program_id: pengajuanBansos.program_id,
      total: sql<number>`COUNT(*)`,
    })
    .from(pengajuanBansos)
    .where(eq(pengajuanBansos.status, "Disetujui"))
    .groupBy(pengajuanBansos.program_id);
  return new Map(rows.map(r => [r.program_id, Number(r.total)]));
}

export async function daftarProgramBansos(termasukDitutup: boolean) {
  const filter = termasukDitutup ? undefined : eq(programBansos.aktif, true);
  const [programs, petaTerpakai] = await Promise.all([
    db
      .select()
      .from(programBansos)
      .where(filter)
      .orderBy(desc(programBansos.is_pinned), desc(programBansos.id)),
    hitungDisetujuiPerProgram(),
  ]);
  return programs.map(p => formatProgram(p, petaTerpakai.get(p.id) ?? 0));
}

export async function ambilDetailProgramBansos(id: number, termasukDitutup: boolean) {
  const filter = termasukDitutup
    ? eq(programBansos.id, id)
    : and(eq(programBansos.id, id), eq(programBansos.aktif, true));
  const [row] = await db.select().from(programBansos).where(filter).limit(1);
  if (!row) {
    throw new KesalahanKatalog(404, "Program bansos tidak ditemukan.");
  }
  const [[hitung]] = await db
    .select({ total: sql<number>`COUNT(*)` })
    .from(pengajuanBansos)
    .where(and(eq(pengajuanBansos.program_id, id), eq(pengajuanBansos.status, "Disetujui")))
    .then(r => [r]);
  return formatProgram(row, Number(hitung?.total ?? 0));
}

export async function ambilFotoBansos(id: number) {
  const [row] = await db.select().from(programBansos).where(eq(programBansos.id, id)).limit(1);
  if (!row || !row.foto_key) {
    throw new KesalahanKatalog(404, "Foto program bansos tidak ditemukan.");
  }
  return bacaFoto(row.foto_key);
}

export async function simpanProgramBansos(
  id: number | undefined,
  isian: Record<string, unknown>,
  file: Express.Multer.File | undefined,
) {
  const lama = id
    ? (await db.select().from(programBansos).where(eq(programBansos.id, id)).limit(1))[0]
    : undefined;
  if (id && !lama) {
    throw new KesalahanKatalog(404, "Program bansos tidak ditemukan.");
  }

  const nama = namaValid(isian.nama ?? isian.judul ?? lama?.nama, 150, "Nama program");
  const deskripsi = teksOpsional(isian.deskripsi ?? lama?.deskripsi ?? "", 1000, "Deskripsi program");
  const jenis_bantuan = teksOpsional(
    isian.jenis_bantuan ?? lama?.jenis_bantuan ?? "Bantuan warga",
    150,
    "Jenis bantuan",
  );
  const persyaratan = teksOpsional(isian.persyaratan ?? lama?.persyaratan ?? "", 1000, "Persyaratan");
  const kuota = bilanganBulat(isian.kuota ?? lama?.kuota ?? 10, 1, "Kuota bantuan");
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
        .update(programBansos)
        .set({ nama, deskripsi, jenis_bantuan, persyaratan, kuota, aktif, is_pinned, foto_key })
        .where(eq(programBansos.id, id));
      idTersimpan = id;
    } else {
      const [hasil] = await db.insert(programBansos).values({
        nama,
        deskripsi,
        jenis_bantuan,
        persyaratan,
        kuota,
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

  return ambilDetailProgramBansos(idTersimpan, true);
}

export async function ubahPinBansos(id: number, isPinned: boolean) {
  const [lama] = await db.select().from(programBansos).where(eq(programBansos.id, id)).limit(1);
  if (!lama) {
    throw new KesalahanKatalog(404, "Program bansos tidak ditemukan.");
  }
  await db.update(programBansos).set({ is_pinned: isPinned }).where(eq(programBansos.id, id));
  return ambilDetailProgramBansos(id, true);
}

export async function hapusProgramBansos(id: number) {
  const [lama] = await db.select().from(programBansos).where(eq(programBansos.id, id)).limit(1);
  if (!lama) {
    throw new KesalahanKatalog(404, "Program bansos tidak ditemukan.");
  }
  await db.delete(programBansos).where(eq(programBansos.id, id));
  await bersihkanFotoAman(lama.foto_key);
}

export async function ajukanBansos(
  programId: number,
  warga: { id: number; nama: string },
  isian: Record<string, unknown>,
) {
  const nama_pemohon = namaValid(isian.nama_pemohon ?? warga.nama, 100, "Nama pemohon");
  const keterangan = namaValid(isian.keterangan, 1000, "Keterangan pengajuan");

  return db.transaction(async tx => {
    const [program] = await tx
      .select()
      .from(programBansos)
      .where(eq(programBansos.id, programId))
      .for("share");
    if (!program) {
      throw new KesalahanKatalog(404, "Program bansos tidak ditemukan.");
    }
    if (!program.aktif) {
      throw new KesalahanKatalog(409, "Program bansos sudah ditutup.");
    }
    const [hitung] = await tx
      .select({ total: sql<number>`COUNT(*)` })
      .from(pengajuanBansos)
      .where(and(eq(pengajuanBansos.program_id, programId), eq(pengajuanBansos.status, "Disetujui")));
    if (Number(hitung?.total ?? 0) >= program.kuota) {
      throw new KesalahanKatalog(409, "Kuota program bansos sudah penuh.");
    }

    try {
      const [hasil] = await tx.insert(pengajuanBansos).values({
        program_id: programId,
        warga_id: warga.id,
        nama_pemohon,
        keterangan,
        status: "Menunggu verifikasi",
      });
      const [baru] = await tx
        .select()
        .from(pengajuanBansos)
        .where(eq(pengajuanBansos.id, hasil.insertId))
        .limit(1);
      return { ...baru, nama_program: program.nama };
    } catch (err) {
      if (kodeMysql(err) === "ER_DUP_ENTRY") {
        throw new KesalahanKatalog(409, "Anda sudah mengirim pengajuan untuk program bansos ini.");
      }
      throw err;
    }
  });
}

export async function daftarPengajuanBansos(wargaId?: number) {
  const query = db
    .select({
      id: pengajuanBansos.id,
      program_id: pengajuanBansos.program_id,
      nama_program: programBansos.nama,
      warga_id: pengajuanBansos.warga_id,
      email_warga: users.email,
      nama_pemohon: pengajuanBansos.nama_pemohon,
      keterangan: pengajuanBansos.keterangan,
      status: pengajuanBansos.status,
      dibuat: pengajuanBansos.dibuat,
    })
    .from(pengajuanBansos)
    .innerJoin(programBansos, eq(pengajuanBansos.program_id, programBansos.id))
    .innerJoin(users, eq(pengajuanBansos.warga_id, users.id));

  return (wargaId === undefined ? query : query.where(eq(pengajuanBansos.warga_id, wargaId)))
    .orderBy(desc(pengajuanBansos.id));
}

export async function tinjauPengajuanBansos(id: number, statusBaru: unknown) {
  if (statusBaru !== "Disetujui" && statusBaru !== "Ditolak") {
    throw new KesalahanKatalog(400, "Pilih status Disetujui atau Ditolak.");
  }

  return db.transaction(async tx => {
    const [lama] = await tx
      .select()
      .from(pengajuanBansos)
      .where(eq(pengajuanBansos.id, id))
      .for("update");
    if (!lama) {
      throw new KesalahanKatalog(404, "Pengajuan bansos tidak ditemukan.");
    }
    if (lama.status !== "Menunggu verifikasi") {
      throw new KesalahanKatalog(409, "Pengajuan bansos ini sudah diperiksa sebelumnya.");
    }

    const [program] = await tx
      .select()
      .from(programBansos)
      .where(eq(programBansos.id, lama.program_id))
      .for("update");
    if (!program) {
      throw new KesalahanKatalog(404, "Program bansos tidak ditemukan.");
    }

    if (statusBaru === "Disetujui") {
      const [hitung] = await tx
        .select({ total: sql<number>`COUNT(*)` })
        .from(pengajuanBansos)
        .where(
          and(
            eq(pengajuanBansos.program_id, program.id),
            eq(pengajuanBansos.status, "Disetujui"),
          ),
        );
      if (Number(hitung?.total ?? 0) >= program.kuota) {
        throw new KesalahanKatalog(409, "Kuota program bansos sudah penuh.");
      }
    }

    await tx.update(pengajuanBansos).set({ status: statusBaru }).where(eq(pengajuanBansos.id, id));
    return {
      ...lama,
      status: statusBaru,
      nama_program: program.nama,
    };
  });
}
