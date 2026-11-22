import type { ErrorRequestHandler } from "express";

export class KesalahanKatalog extends Error {
  constructor(readonly status: number, pesan: string) {
    super(pesan);
  }
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

export const tanganiError: ErrorRequestHandler = (error, _req, res, _next) => {
  if (error instanceof KesalahanKatalog) {
    res.status(error.status).json({ pesan: error.message });
    return;
  }
  switch (kodeMysql(error)) {
    case "ER_DUP_ENTRY":
      res.status(409).json({ pesan: "Data sudah ada dan tidak boleh duplikat." });
      return;
    case "ER_ROW_IS_REFERENCED":
    case "ER_ROW_IS_REFERENCED_2":
      res.status(409).json({ pesan: "Data masih digunakan oleh catatan lain sehingga tidak dapat dihapus." });
      return;
    case "ER_NO_REFERENCED_ROW":
    case "ER_NO_REFERENCED_ROW_2":
      res.status(400).json({ pesan: "Referensi data tidak ditemukan." });
      return;
  }
  if (error.type === "entity.parse.failed" || error.status === 413) {
    res.status(error.status === 413 ? 413 : 400).json({ pesan: "Isi permintaan tidak valid." });
    return;
  }
  res.status(503).json({ pesan: "Layanan belum tersedia." });
};
