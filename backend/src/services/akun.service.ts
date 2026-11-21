import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { eq, sql } from "drizzle-orm";
import type { ProcedureCallPacket, RowDataPacket } from "mysql2/promise";
import { authDb, pegawaiPool } from "../config/db";
import { users } from "../config/schema";

const profil = { id: users.id, nama: users.nama, email: users.email, role: users.role };

export async function daftarkanAkun(
  nama: string,
  email: string,
  password: string,
  role: "warga" | "pegawai",
) {
  const hash = await bcrypt.hash(password, 10);
  try {
    const id = role === "warga"
      ? await tambahWarga(nama, email, hash)
      : await tambahPegawai(nama, email, hash);
    return { id, nama, email, role };
  } catch (error) {
    if (emailDuplikat(error)) {
      return null;
    }
    throw error;
  }
}

export async function periksaLogin(email: string, password: unknown) {
  const user = email ? await cariUntukLogin(email) : undefined;
  const sandiBisaDiperiksa = typeof password === "string" && Buffer.byteLength(password) <= 72;
  if (!user || !sandiBisaDiperiksa) {
    return null;
  }
  const sandiCocok = await bcrypt.compare(password, user.passwordHash);
  if (!sandiCocok) {
    return null;
  }
  const { id, nama, role } = user;
  return { token: buatToken(id), user: { id, nama, email: user.email, role } };
}

async function tambahWarga(nama: string, email: string, hash: string) {
  return authDb.transaction(async tx => {
    const [result] = await tx.execute(sql`
      INSERT INTO users (nama, email, password_hash) VALUES (${nama}, ${email}, ${hash})
    `);
    const [akun] = await tx
      .select({ role: users.role })
      .from(users)
      .where(eq(users.id, result.insertId));
    // Batalkan pendaftaran jika database masih memakai default lama.
    if (akun?.role !== "warga") {
      throw new Error("Default role warga belum tersedia.");
    }
    return result.insertId;
  });
}

async function tambahPegawai(nama: string, email: string, hash: string) {
  if (!process.env.PEGAWAI_DB_USER || !process.env.PEGAWAI_DB_PASSWORD) {
    throw new Error("Koneksi pembuatan pegawai belum siap.");
  }
  const [hasil] = await pegawaiPool.execute<ProcedureCallPacket<(RowDataPacket & { id: number })[]>>(
    "CALL tambah_pegawai(?, ?, ?)", [nama, email, hash],
  );
  return hasil[0][0].id;
}

async function cariUntukLogin(email: string) {
  const [user] = await authDb
    .select({ ...profil, passwordHash: users.passwordHash })
    .from(users)
    .where(eq(users.email, email))
    .limit(1);
  return user;
}

export async function ambilProfil(id: number) {
  const [user] = await authDb.select(profil).from(users).where(eq(users.id, id)).limit(1);
  return user;
}

function emailDuplikat(error: unknown): boolean {
  if (typeof error !== "object" || error === null) {
    return false;
  }
  if ("code" in error && error.code === "ER_DUP_ENTRY") {
    return true;
  }

  return error instanceof Error && emailDuplikat(error.cause);
}

function jwtSecret() {
  const key = process.env.JWT_SECRET;
  if (!key || Buffer.byteLength(key) < 32) {
    throw new Error("Kunci JWT belum siap");
  }

  return key;
}

function buatToken(id: number) {
  return jwt.sign({}, jwtSecret(), {
    algorithm: "HS256", subject: String(id), issuer: "rakrapi", expiresIn: "1h",
  });
}

export function idPenggunaDariToken(authorization: string | undefined): number | undefined {
  // Kata Bearer, satu spasi, lalu token tanpa spasi.
  const polaBearer = /^Bearer ([^\s]+)$/i;
  const bearer = polaBearer.exec(authorization ?? "");
  if (!bearer) {
    return undefined;
  }

  const key = jwtSecret();
  try {
    const claims = jwt.verify(bearer[1], key, { algorithms: ["HS256"], issuer: "rakrapi" });
    if (typeof claims === "string" || typeof claims.sub !== "string") {
      return undefined;
    }

    // verify memeriksa waktu exp jika ada; aplikasi mewajibkan batas waktunya.
    if (typeof claims.exp !== "number" || !Number.isFinite(claims.exp)) {
      return undefined;
    }

    // Klaim sub berisi ID pengguna: 1–10 digit, tanpa nol di depan.
    const polaIdPengguna = /^[1-9]\d{0,9}$/;
    if (!polaIdPengguna.test(claims.sub)) {
      return undefined;
    }

    return Number(claims.sub);
  } catch {
    // Token tidak sah atau kedaluwarsa.
    return undefined;
  }
}
