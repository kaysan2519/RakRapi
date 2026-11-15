export class KesalahanKatalog extends Error {
  constructor(readonly status: number, pesan: string) {
    super(pesan);
  }
}

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

export function namaValid(value: unknown, max: number) {
  const nama = typeof value === "string" ? value.trim() : "";

  if (!nama || Array.from(nama).length > max) {
    throw new KesalahanKatalog(400, `Nama wajib diisi, maksimal ${max} karakter.`);
  }
  return nama;
}

export function kodeMysql(error: unknown): string | undefined {
  if (!(error instanceof Error)) {
    return undefined;
  }
  if ("code" in error && typeof error.code === "string") {
    return error.code;
  }

  return kodeMysql(error.cause);
}
