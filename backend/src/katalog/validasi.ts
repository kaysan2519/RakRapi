export class KesalahanKatalog extends Error {
  constructor(readonly status: number, pesan: string) { super(pesan); }
}

export function bilanganBulat(value: unknown, min: number, label: string): number {
  if ((typeof value !== "string" && typeof value !== "number") ||
      !/^\d+$/.test(String(value)) || Number(value) < min || Number(value) > 4294967295) {
    throw new KesalahanKatalog(400, `${label} tidak valid.`);
  }
  return Number(value);
}

export function namaValid(value: unknown, max: number) {
  const nama = typeof value === "string" ? value.trim() : "";
  if (!nama || Array.from(nama).length > max) {
    throw new KesalahanKatalog(400, `Nama wajib diisi, maksimal ${max} karakter.`);
  }
  return nama;
}

export function kodeMysql(error: unknown): string | undefined {
  if (!(error instanceof Error)) return undefined;
  if ("code" in error && typeof error.code === "string") return error.code;
  return kodeMysql(error.cause);
}
