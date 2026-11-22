import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { and, asc, eq, sql } from "drizzle-orm";
import { db } from "../config/db";
import { users } from "../config/schema";
import { KesalahanKatalog } from "../middleware/error.middleware";

const profil = {
  id: users.id,
  nama: users.nama,
  email: users.email,
  role: users.role,
  status: users.status,
  alasan_pemberhentian: users.alasan_pemberhentian,
  diberhentikan_pada: users.diberhentikan_pada,
};

function saltRounds(): number {
  const nilai = Number(process.env.BCRYPT_SALT_ROUNDS ?? 12);
  if (!Number.isInteger(nilai) || nilai < 10 || nilai > 14) {
    return 12;
  }
  return nilai;
}

function masaBerlakuToken(): jwt.SignOptions["expiresIn"] {
  const nilai = process.env.JWT_EXPIRES_IN?.trim();
  return (nilai || "1h") as jwt.SignOptions["expiresIn"];
}

export async function daftarkanAkun(
  nama: string,
  email: string,
  password: string,
  role: "warga" | "pegawai",
) {
  const hash = await bcrypt.hash(password, saltRounds());
  try {
    const [hasil] = await db.insert(users).values({ nama, email, passwordHash: hash, role });
    return {
      id: hasil.insertId,
      nama,
      email,
      role,
      status: "aktif" as const,
      alasan_pemberhentian: null,
      diberhentikan_pada: null,
    };
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
  if (user.status !== "aktif") {
    throw new KesalahanKatalog(
      403,
      "Akun pegawai ini telah diberhentikan dan tidak lagi memiliki akses ke aplikasi.",
    );
  }
  const { id, nama, role, status } = user;
  return { token: buatToken(id), user: { id, nama, email: user.email, role, status } };
}

async function cariUntukLogin(email: string) {
  const [user] = await db
    .select({ ...profil, passwordHash: users.passwordHash })
    .from(users)
    .where(eq(users.email, email))
    .limit(1);
  return user;
}

export async function ambilProfil(id: number) {
  const [user] = await db.select(profil).from(users).where(eq(users.id, id)).limit(1);
  return user;
}

export async function daftarPegawai(statusFilter?: "aktif" | "diberhentikan") {
  const kondisi = statusFilter
    ? and(eq(users.role, "pegawai"), eq(users.status, statusFilter))
    : eq(users.role, "pegawai");
  return db
    .select(profil)
    .from(users)
    .where(kondisi)
    .orderBy(asc(users.status), asc(users.nama), asc(users.id));
}

export async function ambilDetailPegawai(id: number) {
  const [pegawai] = await db
    .select(profil)
    .from(users)
    .where(and(eq(users.id, id), eq(users.role, "pegawai")))
    .limit(1);
  if (!pegawai) {
    throw new KesalahanKatalog(404, "Pegawai tidak ditemukan.");
  }
  return pegawai;
}

export async function berhentikanPegawai(id: number, alasan: string) {
  await db.transaction(async tx => {
    const [target] = await tx.select(profil).from(users).where(eq(users.id, id)).for("update");
    if (!target) {
      throw new KesalahanKatalog(404, "Pegawai tidak ditemukan.");
    }
    if (target.role !== "pegawai") {
      throw new KesalahanKatalog(403, "Hanya akun pegawai yang dapat diberhentikan.");
    }
    if (target.status === "diberhentikan") {
      throw new KesalahanKatalog(409, "Pegawai ini sudah diberhentikan sebelumnya.");
    }
    await tx
      .update(users)
      .set({
        status: "diberhentikan",
        alasan_pemberhentian: alasan,
        diberhentikan_pada: sql`CURRENT_TIMESTAMP`,
      })
      .where(eq(users.id, id));
  });
  return ambilDetailPegawai(id);
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

function jwtSecret(): string {
  const key = process.env.JWT_SECRET;
  if (!key || Buffer.byteLength(key) < 32) {
    throw new Error("Kunci JWT belum siap.");
  }
  return key;
}

function buatToken(id: number) {
  return jwt.sign({}, jwtSecret(), {
    algorithm: "HS256",
    subject: String(id),
    issuer: "rakrapi",
    expiresIn: masaBerlakuToken(),
  });
}

export function idPenggunaDariToken(authorization: string | undefined): number | undefined {
  // Format wajib: "Bearer <token>"
  const bearer = /^Bearer ([^\s]+)$/i.exec(authorization ?? "");
  if (!bearer) {
    return undefined;
  }

  const key = jwtSecret();
  try {
    const claims = jwt.verify(bearer[1], key, { algorithms: ["HS256"], issuer: "rakrapi" });
    if (typeof claims === "string" || typeof claims.sub !== "string") {
      return undefined;
    }
    if (typeof claims.exp !== "number" || !Number.isFinite(claims.exp)) {
      return undefined;
    }
    if (!/^[1-9]\d{0,9}$/.test(claims.sub)) {
      return undefined;
    }
    return Number(claims.sub);
  } catch {
    return undefined;
  }
}
