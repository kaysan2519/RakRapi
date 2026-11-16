import { execFile } from "node:child_process";
import { KesalahanKatalog } from "../middleware/error.middleware";

export const batasByteFoto = 5 * 1024 * 1024;
const pesanFotoTidakValid = "Gunakan foto JPEG atau PNG yang valid, maksimal 16 megapiksel.";

function formatFoto(file: Express.Multer.File): "png" | "jpg" {
  const bytes = file.buffer;
  if (bytes.length > batasByteFoto) {
    throw new KesalahanKatalog(413, "Foto maksimal 5 MiB.");
  }

  // Cocokkan tipe yang dikirim dengan penanda awal dan akhir file.
  const awalPng = Buffer.from("89504e470d0a1a0a", "hex");
  const akhirPng = Buffer.from("0000000049454e44ae426082", "hex");
  const penandaPngCocok = bytes.subarray(0, 8).equals(awalPng)
    && bytes.subarray(-12).equals(akhirPng);
  const awalJpegCocok = bytes[0] === 255 && bytes[1] === 216;
  const akhirJpegCocok = bytes.at(-2) === 255 && bytes.at(-1) === 217;

  if (file.mimetype === "image/png" && penandaPngCocok) {
    return "png";
  }
  if (file.mimetype === "image/jpeg" && awalJpegCocok && akhirJpegCocok) {
    return "jpg";
  }
  throw new KesalahanKatalog(415, pesanFotoTidakValid);
}

// Decoder bawaan Windows membaca byte dari stdin. Nama file klien tidak dipakai.
const decodeGambar = `
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$stream=New-Object IO.MemoryStream
[Console]::OpenStandardInput().CopyTo($stream)
$stream.Position=0
try {
  $img=[Drawing.Image]::FromStream($stream,$false,$false)
  if ([long]$img.Width * $img.Height -gt 16000000) {
    exit 2
  }
  if ($img.RawFormat.Guid -eq [Drawing.Imaging.ImageFormat]::Png.Guid) {
    $type='png'
  } elseif ($img.RawFormat.Guid -eq [Drawing.Imaging.ImageFormat]::Jpeg.Guid) {
    $type='jpg'
  } else {
    exit 2
  }
  $bitmap=[Drawing.Bitmap]::new($img)
  $bitmap.Dispose()
  [Console]::Write($type)
} catch {
  exit 2
} finally {
  if ($img) {
    $img.Dispose()
  }
  $stream.Dispose()
}
`;

export async function periksaFoto(file: Express.Multer.File) {
  const ekstensi = formatFoto(file);
  const bytes = file.buffer;

  const formatDariDecoder = await new Promise<string>((resolve, reject) => {
    const proc = execFile("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", decodeGambar],
      { windowsHide: true, timeout: 15000 }, (error, stdout) => {
        if (!error) {
          resolve(stdout.trim());
        } else if (error.code === 2) {
          reject(new KesalahanKatalog(415, pesanFotoTidakValid));
        } else {
          reject(error);
        }
      });
    proc.stdin?.on("error", () => { /* exit decoder ditangani di callback */ });
    proc.stdin?.end(bytes);
  });
  if (formatDariDecoder !== ekstensi) {
    throw new KesalahanKatalog(415, pesanFotoTidakValid);
  }

  return ekstensi;
}
