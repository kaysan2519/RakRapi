import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { eq } from "drizzle-orm";
import { db } from "../config/db";
import { users } from "../config/schema";

const profil = { id: users.id, nama: users.nama, email: users.email, role: users.role };

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
    return { id: hasil.insertId, nama, email, role };
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
