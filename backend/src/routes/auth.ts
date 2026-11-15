import bcrypt from "bcryptjs";
import { Router, type RequestHandler } from "express";
import { buatToken, perluLogin, perluRole } from "../auth/session";
import { cariUntukLogin, tambahPegawai } from "../auth/users";

export const authRouter = Router();

function emailDari(input: unknown) {
  if (typeof input !== "string") return "";
  const email = input.trim().toLowerCase();
  return email.length <= 255 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : "";
}

function emailDuplikat(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;
  if ("code" in error && error.code === "ER_DUP_ENTRY") return true;
  return error instanceof Error && emailDuplikat(error.cause);
}

export const register: RequestHandler = async (req, res) => {
  const nama = typeof req.body?.nama === "string" ? req.body.nama.trim() : "";
  const email = emailDari(req.body?.email);
  const password: unknown = req.body?.password;
  if (!nama || nama.length > 100 || !email || typeof password !== "string" ||
      password.length < 8 || Buffer.byteLength(password) > 72) {
    res.status(400).json({ pesan: "Isi nama, email valid, dan sandi minimal 8 karakter, maksimal 72 byte." });
    return;
  }
  const hash = await bcrypt.hash(password, 10);
  try {
    const id = await tambahPegawai(nama, email, hash);
    res.status(201).json({ user: { id, nama, email, role: "pegawai" } });
  } catch (err) {
    if (!emailDuplikat(err)) throw err;
    res.status(409).json({ pesan: "Email sudah terdaftar." });
  }
};

export const login: RequestHandler = async (req, res) => {
  const email = emailDari(req.body?.email);
  const password: unknown = req.body?.password;
  const user = email ? await cariUntukLogin(email) : undefined;
  if (!user || typeof password !== "string" || Buffer.byteLength(password) > 72 ||
      !await bcrypt.compare(password, user.passwordHash)) {
    res.status(401).json({ pesan: "Email atau sandi salah." });
    return;
  }
  const { id, nama, role } = user;
  res.json({ token: buatToken(id), user: { id, nama, email: user.email, role } });
};

authRouter.use((_req, res, next) => { res.set("Cache-Control", "no-store"); next(); });
authRouter.post("/register", register);
authRouter.post("/login", login);
authRouter.get("/me", perluLogin, (_req, res) => res.json({ user: res.locals.user }));
authRouter.get("/pemilik", perluLogin, perluRole("pemilik"), (_req, res) => {
  res.json({ pesan: "Akses pemilik diterima." });
});
