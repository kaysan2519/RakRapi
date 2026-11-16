export function emailDari(input: unknown) {
  if (typeof input !== "string") {
    return "";
  }

  const email = input.trim().toLowerCase();
  // Contoh: nama@domain.id, tanpa spasi atau tanda @ tambahan.
  const polaEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (email.length > 255 || !polaEmail.test(email)) {
    return "";
  }

  return email;
}

export function validasiAkun(namaMasukan: unknown, emailMasukan: unknown, password: unknown) {
  const nama = typeof namaMasukan === "string" ? namaMasukan.trim() : "";
  const email = emailDari(emailMasukan);
  const namaValid = nama.length > 0 && nama.length <= 100;
  const sandiValid = typeof password === "string"
    && password.length >= 8
    && Buffer.byteLength(password) <= 72;

  if (!namaValid || !email || !sandiValid) {
    return null;
  }
  return { nama, email, password };
}
