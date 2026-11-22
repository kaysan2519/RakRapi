import { sql } from "drizzle-orm";
import {
  boolean,
  char,
  datetime,
  decimal,
  int,
  mysqlEnum,
  mysqlTable,
  tinyint,
  varchar,
} from "drizzle-orm/mysql-core";

export const users = mysqlTable("users", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  nama: varchar("nama", { length: 100 }).notNull(),
  email: varchar("email", { length: 255 }).notNull(),
  passwordHash: varchar("password_hash", { length: 255 }).notNull(),
  role: varchar("role", { length: 10, enum: ["pemilik", "pegawai", "warga"] }).notNull(),
  status: mysqlEnum("status", ["aktif", "diberhentikan"]).notNull().default("aktif"),
  alasan_pemberhentian: varchar("alasan_pemberhentian", { length: 500 }),
  diberhentikan_pada: datetime("diberhentikan_pada", { mode: "string" }),
});

export type Role = typeof users.$inferSelect.role;

export const kategori = mysqlTable("kategori", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  nama: varchar("nama", { length: 100 }).notNull(),
});

export const barang = mysqlTable("barang", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  kategori_id: int("kategori_id", { unsigned: true }).notNull(),
  nama: varchar("nama", { length: 150 }).notNull(),
  harga_rupiah: int("harga_rupiah", { unsigned: true }).notNull(),
  stok: decimal("stok", { precision: 12, scale: 3 }).notNull(),
  satuan: varchar("satuan", { length: 20 }).notNull(),
  deskripsi: varchar("deskripsi", { length: 500 }).notNull().default(""),
  foto_key: varchar("foto_key", { length: 255 }).notNull(),
});

export const pesanan = mysqlTable("pesanan", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  warga_id: int("warga_id", { unsigned: true }).notNull(),
  nama_pemesan: varchar("nama_pemesan", { length: 100 }).notNull(),
  kunci_kirim: char("kunci_kirim", { length: 32 }).notNull(),
  status: mysqlEnum("status", [
    "Menunggu konfirmasi",
    "Dikonfirmasi",
    "Siap diambil",
    "Selesai",
  ])
    .notNull()
    .default("Menunggu konfirmasi"),
  metode_pembayaran: mysqlEnum("metode_pembayaran", [
    "Bayar di kasir",
    "Transfer bank",
  ])
    .notNull()
    .default("Bayar di kasir"),
  status_pembayaran: mysqlEnum("status_pembayaran", [
    "Belum dibayar",
    "Sudah dibayar",
  ])
    .notNull()
    .default("Belum dibayar"),
  total_rupiah: decimal("total_rupiah", { precision: 32, scale: 0 }).notNull(),
  dibuat: datetime("dibuat", { mode: "string" }).notNull().default(sql`CURRENT_TIMESTAMP`),
});

export const detailPesanan = mysqlTable("detail_pesanan", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  pesanan_id: int("pesanan_id", { unsigned: true }).notNull(),
  barang_id: int("barang_id", { unsigned: true }),
  nama_barang: varchar("nama_barang", { length: 150 }).notNull(),
  satuan: varchar("satuan", { length: 20 }).notNull(),
  jumlah: decimal("jumlah", { precision: 12, scale: 3 }).notNull(),
  harga_rupiah: int("harga_rupiah", { unsigned: true }).notNull(),
});

export const lowongan = mysqlTable("lowongan", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  judul: varchar("judul", { length: 150 }).notNull(),
  deskripsi: varchar("deskripsi", { length: 1000 }).notNull().default(""),
  persyaratan: varchar("persyaratan", { length: 1000 }).notNull().default(""),
  lokasi: varchar("lokasi", { length: 150 }).notNull().default("Toko RakRapi"),
  info_tambahan: varchar("info_tambahan", { length: 150 }).notNull().default(""),
  foto_key: varchar("foto_key", { length: 255 }),
  aktif: boolean("aktif").notNull().default(true),
  is_pinned: boolean("is_pinned").notNull().default(false),
  dibuat: datetime("dibuat", { mode: "string" }).notNull().default(sql`CURRENT_TIMESTAMP`),
});

export const lamaran = mysqlTable("lamaran", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  lowongan_id: int("lowongan_id", { unsigned: true }).notNull(),
  warga_id: int("warga_id", { unsigned: true }).notNull(),
  nama_pelamar: varchar("nama_pelamar", { length: 100 }).notNull(),
  keterangan: varchar("keterangan", { length: 1000 }).notNull(),
  status: mysqlEnum("status", [
    "Menunggu verifikasi",
    "Disetujui",
    "Ditolak",
  ])
    .notNull()
    .default("Menunggu verifikasi"),
  dibuat: datetime("dibuat", { mode: "string" }).notNull().default(sql`CURRENT_TIMESTAMP`),
});

export const programBansos = mysqlTable("program_bansos", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  nama: varchar("nama", { length: 150 }).notNull(),
  deskripsi: varchar("deskripsi", { length: 1000 }).notNull().default(""),
  jenis_bantuan: varchar("jenis_bantuan", { length: 150 }).notNull().default(""),
  persyaratan: varchar("persyaratan", { length: 1000 }).notNull().default(""),
  kuota: int("kuota", { unsigned: true }).notNull().default(1),
  foto_key: varchar("foto_key", { length: 255 }),
  aktif: boolean("aktif").notNull().default(true),
  is_pinned: boolean("is_pinned").notNull().default(false),
  dibuat: datetime("dibuat", { mode: "string" }).notNull().default(sql`CURRENT_TIMESTAMP`),
});

export const pengajuanBansos = mysqlTable("pengajuan_bansos", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  program_id: int("program_id", { unsigned: true }).notNull(),
  warga_id: int("warga_id", { unsigned: true }).notNull(),
  nama_pemohon: varchar("nama_pemohon", { length: 100 }).notNull(),
  keterangan: varchar("keterangan", { length: 1000 }).notNull(),
  status: mysqlEnum("status", [
    "Menunggu verifikasi",
    "Disetujui",
    "Ditolak",
  ])
    .notNull()
    .default("Menunggu verifikasi"),
  dibuat: datetime("dibuat", { mode: "string" }).notNull().default(sql`CURRENT_TIMESTAMP`),
});

export const pengumuman = mysqlTable("pengumuman", {
  id: int("id", { unsigned: true }).primaryKey().autoincrement(),
  judul: varchar("judul", { length: 150 }).notNull(),
  deskripsi: varchar("deskripsi", { length: 1000 }).notNull().default(""),
  jenis: mysqlEnum("jenis", ["Pengumuman", "Diskon", "Informasi toko"])
    .notNull()
    .default("Pengumuman"),
  info_tambahan: varchar("info_tambahan", { length: 150 }).notNull().default(""),
  foto_key: varchar("foto_key", { length: 255 }),
  aktif: boolean("aktif").notNull().default(true),
  is_pinned: boolean("is_pinned").notNull().default(false),
  dibuat: datetime("dibuat", { mode: "string" }).notNull().default(sql`CURRENT_TIMESTAMP`),
});

export const infoToko = mysqlTable("info_toko", {
  id: tinyint("id", { unsigned: true }).primaryKey(),
  nama_toko: varchar("nama_toko", { length: 150 }).notNull().default("Toko Sembako RakRapi"),
  alamat: varchar("alamat", { length: 300 }).notNull().default(""),
  jam_operasional: varchar("jam_operasional", { length: 150 }).notNull().default(""),
  kontak: varchar("kontak", { length: 100 }).notNull().default(""),
  info_pengambilan: varchar("info_pengambilan", { length: 300 }).notNull().default("Ambil di kasir toko setelah status pesanan Siap diambil."),
  nama_bank: varchar("nama_bank", { length: 100 }),
  nomor_rekening: varchar("nomor_rekening", { length: 50 }),
  nama_pemilik_rekening: varchar("nama_pemilik_rekening", { length: 150 }),
  diperbarui: datetime("diperbarui", { mode: "string" }).notNull().default(sql`CURRENT_TIMESTAMP`),
});
