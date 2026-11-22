import type { ErrorRequestHandler } from "express";

export class KesalahanKatalog extends Error {
  constructor(readonly status: number, pesan: string) {
    super(pesan);
  }
}

function kodeMysql(error: unknown): string | undefined {
  if (!(error instanceof Error)) {
    return undefined;
  }
  if ("code" in error && typeof error.code === "string") {
    return error.code;
  }

  return kodeMysql(error.cause);
}

export const tanganiError: ErrorRequestHandler = (error, _req, res, _next) => {
  if (error instanceof KesalahanKatalog) {
    res.status(error.status).json({ pesan: error.message });
    return;
  }
  switch (kodeMysql(error)) {
    case "ER_DUP_ENTRY":
      res.status(409).json({ pesan: "Nama kategori sudah digunakan." });
      return;
    case "ER_ROW_IS_REFERENCED":
    case "ER_ROW_IS_REFERENCED_2":
      res.status(409).json({ pesan: "Kategori ini masih digunakan. Kategori bisa dihapus setelah tidak ada barang yang menggunakannya." });
      return;
    case "ER_NO_REFERENCED_ROW":
    case "ER_NO_REFERENCED_ROW_2":
      res.status(400).json({ pesan: "Kategori tidak ditemukan." });
      return;
  }
  if (error.type === "entity.parse.failed" || error.status === 413) {
    res.status(error.status === 413 ? 413 : 400).json({ pesan: "Isi permintaan tidak valid." });
    return;
  }
  res.status(503).json({ pesan: "Layanan belum tersedia." });
};
