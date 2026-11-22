import type { RequestHandler } from "express";
import multer from "multer";
import { batasByteFoto } from "../validations/foto.validation";
import { KesalahanKatalog } from "./error.middleware";

const unggahFoto = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: batasByteFoto + 1, files: 1, fields: 12, parts: 14, fieldSize: 4096 },
}).single("foto");

export const terimaFoto: RequestHandler = (req, res, next) => {
  unggahFoto(req, res, error => {
    if (!error) {
      return next();
    }
    if (error.code === "LIMIT_FILE_SIZE") {
      return next(new KesalahanKatalog(413, "Foto maksimal 5 MiB."));
    }

    next(new KesalahanKatalog(400, "Form tidak valid. Kirim satu file pada kolom foto."));
  });
};
