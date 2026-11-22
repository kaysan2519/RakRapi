import { and, desc, eq, lte, sql } from "drizzle-orm";
import { db } from "../config/db";
import {
  barang,
  infoToko,
  kategori,
  lamaran,
  lowongan,
  pengajuanBansos,
  pengumuman,
  pesanan,
  programBansos,
  users,
} from "../config/schema";
import { KesalahanKatalog } from "../middleware/error.middleware";
import { namaValid, teksOpsional } from "../validations/umum.validation";

export interface ItemPin {
  sumber: "lowongan" | "bansos" | "pengumuman";
  id: number;
  jenis: string;
  judul: string;
  deskripsi: string;
  info_tambahan: string;
  foto_url: string | null;
  aktif: boolean;
  is_pinned: boolean;
  dibuat: string;
}

export async function daftarInformasiPin(hanyaDipin: boolean): Promise<ItemPin[]> {
  const [daftarLow, daftarBan, daftarPeng] = await Promise.all([
    db
      .select()
      .from(lowongan)
      .where(hanyaDipin ? and(eq(lowongan.aktif, true), eq(lowongan.is_pinned, true)) : undefined)
      .orderBy(desc(lowongan.is_pinned), desc(lowongan.id)),
    db
      .select()
      .from(programBansos)
      .where(hanyaDipin ? and(eq(programBansos.aktif, true), eq(programBansos.is_pinned, true)) : undefined)
      .orderBy(desc(programBansos.is_pinned), desc(programBansos.id)),
    db
      .select()
      .from(pengumuman)
      .where(hanyaDipin ? and(eq(pengumuman.aktif, true), eq(pengumuman.is_pinned, true)) : undefined)
      .orderBy(desc(pengumuman.is_pinned), desc(pengumuman.id)),
  ]);

  const hasil: ItemPin[] = [
    ...daftarPeng.map(p => ({
      sumber: "pengumuman" as const,
      id: p.id,
      jenis: p.jenis,
      judul: p.judul,
      deskripsi: p.deskripsi,
      info_tambahan: p.info_tambahan || p.jenis,
      foto_url: p.foto_key ? `/api/pengumuman/${p.id}/foto` : null,
      aktif: p.aktif,
      is_pinned: p.is_pinned,
      dibuat: p.dibuat,
    })),
    ...daftarLow.map(l => ({
      sumber: "lowongan" as const,
      id: l.id,
      jenis: "Lowongan",
      judul: l.judul,
      deskripsi: l.deskripsi,
      info_tambahan: l.info_tambahan || l.lokasi,
      foto_url: l.foto_key ? `/api/lowongan/${l.id}/foto` : null,
      aktif: l.aktif,
      is_pinned: l.is_pinned,
      dibuat: l.dibuat,
    })),
    ...daftarBan.map(b => ({
      sumber: "bansos" as const,
      id: b.id,
      jenis: "Bansos",
      judul: b.nama,
      deskripsi: b.deskripsi,
      info_tambahan: `${b.jenis_bantuan || "Bantuan sosial"} · Kuota ${b.kuota}`,
      foto_url: b.foto_key ? `/api/bansos/${b.id}/foto` : null,
      aktif: b.aktif,
      is_pinned: b.is_pinned,
      dibuat: b.dibuat,
    })),
  ];

  // Urutkan yang dipin paling atas, lalu yang terbaru.
  return hasil.sort((a, b) => Number(b.is_pinned) - Number(a.is_pinned) || b.dibuat.localeCompare(a.dibuat));
}

export async function ambilInfoToko() {
  const [row] = await db.select().from(infoToko).where(eq(infoToko.id, 1)).limit(1);
  if (!row) {
    return {
      nama_toko: "Toko Sembako RakRapi",
      alamat: "",
      jam_operasional: "",
      kontak: "",
      info_pengambilan: "Ambil di kasir toko setelah status pesanan Siap diambil.",
      rekening_tersedia: false,
      nama_bank: null,
      nomor_rekening: null,
      nama_pemilik_rekening: null,
      diperbarui: null,
    };
  }
  const rekening_tersedia = Boolean(
    row.nama_bank?.trim() && row.nomor_rekening?.trim() && row.nama_pemilik_rekening?.trim(),
  );
  return {
    nama_toko: row.nama_toko,
    alamat: row.alamat,
    jam_operasional: row.jam_operasional,
    kontak: row.kontak,
    info_pengambilan: row.info_pengambilan,
    rekening_tersedia,
    nama_bank: rekening_tersedia ? row.nama_bank : null,
    nomor_rekening: rekening_tersedia ? row.nomor_rekening : null,
    nama_pemilik_rekening: rekening_tersedia ? row.nama_pemilik_rekening : null,
    diperbarui: row.diperbarui,
  };
}

export async function perbaruiInfoToko(isian: Record<string, unknown>) {
  const saatIni = await ambilInfoToko();

  const nama_toko = namaValid(isian.nama_toko ?? saatIni.nama_toko, 150, "Nama toko");
  const alamat = teksOpsional(isian.alamat ?? saatIni.alamat, 300, "Alamat toko");
  const jam_operasional = teksOpsional(isian.jam_operasional ?? saatIni.jam_operasional, 150, "Jam operasional");
  const kontak = teksOpsional(isian.kontak ?? saatIni.kontak, 100, "Kontak toko");
  const info_pengambilan = teksOpsional(
    isian.info_pengambilan ?? saatIni.info_pengambilan,
    300,
    "Informasi pengambilan",
  ) || "Ambil di kasir toko setelah status pesanan Siap diambil.";

  // Validasi rekening: isi ketiganya secara lengkap atau kosongkan ketiganya.
  const bankBaru = isian.nama_bank !== undefined ? teksOpsional(isian.nama_bank, 100, "Nama bank") : (saatIni.nama_bank ?? "");
  const rekBaru = isian.nomor_rekening !== undefined ? teksOpsional(isian.nomor_rekening, 50, "Nomor rekening") : (saatIni.nomor_rekening ?? "");
  const pemilikRekBaru = isian.nama_pemilik_rekening !== undefined
    ? teksOpsional(isian.nama_pemilik_rekening, 150, "Nama pemilik rekening")
    : (saatIni.nama_pemilik_rekening ?? "");

  const jumlahIsiRek = [bankBaru, rekBaru, pemilikRekBaru].filter(Boolean).length;
  if (jumlahIsiRek > 0 && jumlahIsiRek < 3) {
    throw new KesalahanKatalog(
      400,
      "Lengkapi nama bank, nomor rekening, dan nama pemilik rekening, atau kosongkan ketiganya.",
    );
  }
  if (rekBaru && !/^[0-9\s-]{6,50}$/.test(rekBaru)) {
    throw new KesalahanKatalog(400, "Nomor rekening hanya boleh berisi angka, spasi, atau tanda hubung (minimal 6 karakter).");
  }

  const nilai = {
    nama_toko,
    alamat,
    jam_operasional,
    kontak,
    info_pengambilan,
    nama_bank: jumlahIsiRek === 3 ? bankBaru : null,
    nomor_rekening: jumlahIsiRek === 3 ? rekBaru : null,
    nama_pemilik_rekening: jumlahIsiRek === 3 ? pemilikRekBaru : null,
  };

  const [ada] = await db.select({ id: infoToko.id }).from(infoToko).where(eq(infoToko.id, 1)).limit(1);
  if (ada) {
    await db.update(infoToko).set(nilai).where(eq(infoToko.id, 1));
  } else {
    await db.insert(infoToko).values({ id: 1, ...nilai });
  }
  return ambilInfoToko();
}

export async function ambilRingkasanDashboard() {
  const [
    [produk],
    [kat],
    [peg],
    [stokTipis],
    [pesananMasuk],
    [pesananDiproses],
    [pesananSelesai],
    [pinLow],
    [pinBan],
    [pinPeng],
    [lamaranMenunggu],
    [bansosMenunggu],
  ] = await Promise.all([
    db.select({ c: sql<number>`COUNT(*)` }).from(barang),
    db.select({ c: sql<number>`COUNT(*)` }).from(kategori),
    db
      .select({ c: sql<number>`COUNT(*)` })
      .from(users)
      .where(and(eq(users.role, "pegawai"), eq(users.status, "aktif"))),
    db.select({ c: sql<number>`COUNT(*)` }).from(barang).where(lte(barang.stok, "5.000")),
    db.select({ c: sql<number>`COUNT(*)` }).from(pesanan).where(eq(pesanan.status, "Menunggu konfirmasi")),
    db.select({ c: sql<number>`COUNT(*)` }).from(pesanan).where(sql`${pesanan.status} IN ('Dikonfirmasi', 'Siap diambil')`),
    db.select({ c: sql<number>`COUNT(*)` }).from(pesanan).where(eq(pesanan.status, "Selesai")),
    db.select({ c: sql<number>`COUNT(*)` }).from(lowongan).where(and(eq(lowongan.aktif, true), eq(lowongan.is_pinned, true))),
    db.select({ c: sql<number>`COUNT(*)` }).from(programBansos).where(and(eq(programBansos.aktif, true), eq(programBansos.is_pinned, true))),
    db.select({ c: sql<number>`COUNT(*)` }).from(pengumuman).where(and(eq(pengumuman.aktif, true), eq(pengumuman.is_pinned, true))),
    db.select({ c: sql<number>`COUNT(*)` }).from(lamaran).where(eq(lamaran.status, "Menunggu verifikasi")),
    db.select({ c: sql<number>`COUNT(*)` }).from(pengajuanBansos).where(eq(pengajuanBansos.status, "Menunggu verifikasi")),
  ]);

  return {
    jumlah_produk: Number(produk?.c ?? 0),
    jumlah_kategori: Number(kat?.c ?? 0),
    jumlah_pegawai: Number(peg?.c ?? 0),
    stok_menipis: Number(stokTipis?.c ?? 0),
    pesanan_masuk: Number(pesananMasuk?.c ?? 0),
    pesanan_diproses: Number(pesananDiproses?.c ?? 0),
    pesanan_selesai: Number(pesananSelesai?.c ?? 0),
    jumlah_pin_aktif: Number(pinLow?.c ?? 0) + Number(pinBan?.c ?? 0) + Number(pinPeng?.c ?? 0),
    lamaran_menunggu: Number(lamaranMenunggu?.c ?? 0),
    bansos_menunggu: Number(bansosMenunggu?.c ?? 0),
  };
}
