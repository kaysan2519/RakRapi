import { KesalahanKatalog } from "../middleware/error.middleware";

export function bilanganBulat(value: unknown, min: number, label: string): number {
  if (typeof value !== "string" && typeof value !== "number") {
    throw new KesalahanKatalog(400, `${label} tidak valid.`);
  }

  // ID dan harga hanya menerima digit, tanpa spasi, tanda, atau pecahan.
  const polaDigit = /^\d+$/;
  const angka = Number(value);
  const maksimumIntUnsigned = 4294967295;
  if (!polaDigit.test(String(value)) || angka < min || angka > maksimumIntUnsigned) {
    throw new KesalahanKatalog(400, `${label} tidak valid.`);
  }

  return angka;
}

export function namaValid(value: unknown, max: number, label = "Nama") {
  const nama = typeof value === "string" ? value.trim() : "";

  if (!nama || Array.from(nama).length > max) {
    throw new KesalahanKatalog(400, `${label} wajib diisi, maksimal ${max} karakter.`);
  }
  return nama;
}

export function teksOpsional(value: unknown, max: number, label: string): string {
  if (value === undefined || value === null) {
    return "";
  }
  if (typeof value !== "string") {
    throw new KesalahanKatalog(400, `${label} tidak valid.`);
  }
  const hasil = value.trim();
  if (Array.from(hasil).length > max) {
    throw new KesalahanKatalog(400, `${label} maksimal ${max} karakter.`);
  }
  return hasil;
}

export function booleanDariInput(value: unknown, defaultNilai: boolean): boolean {
  if (value === undefined || value === null || value === "") {
    return defaultNilai;
  }
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value === "string") {
    const lower = value.trim().toLowerCase();
    if (lower === "true" || lower === "1" || lower === "ya") return true;
    if (lower === "false" || lower === "0" || lower === "tidak") return false;
  }
  throw new KesalahanKatalog(400, "Nilai status tidak valid.");
}
