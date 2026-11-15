// Jalankan dari backend: node --env-file=.env --test test/katalog.cjs
const test = require("node:test");
const assert = require("node:assert/strict");
const { randomUUID } = require("node:crypto");
const { spawn, execFileSync } = require("node:child_process");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const net = require("node:net");
const { once } = require("node:events");
const { setTimeout: wait } = require("node:timers/promises");

const cli = process.env.MYSQL_CLI || "C:/laragon/bin/mysql/mysql-8.0.30-winx64/bin/mysql.exe";
function admin(sql) {
  try {
    return execFileSync(cli, ["--login-path=rakrapi", "--protocol=TCP", "--host=127.0.0.1",
      "--port=3306", "--batch", "--raw", "--skip-column-names"], {
      input: sql, encoding: "utf8", windowsHide: true, stdio: ["pipe", "pipe", "pipe"],
    }).trimEnd();
  } catch { throw new Error("Perintah penyiapan/pembersihan MySQL uji gagal."); }
}

test("katalog lokal melalui HTTP", async (t) => {
  const tag = randomUUID().replaceAll("-", "").slice(0, 16);
  const schema = "rakrapi_uji_" + tag;
  const account = "uji_" + tag;
  const folder = await fs.mkdtemp(path.join(os.tmpdir(), "rakrapi-foto-"));
  let dibuatDB = false, dibuatAkun = false, password, app, url;
  let pemilik, pegawai;
  async function start() {
    const listener = net.createServer().listen(0, "127.0.0.1");
    await once(listener, "listening");
    const port = listener.address().port;
    await new Promise(resolve => listener.close(resolve));
    const env = { ...process.env, PORT: String(port), CATALOG_DB_NAME: schema,
      CATALOG_DB_USER: account, CATALOG_DB_PASSWORD: password, UPLOAD_DIR: folder };
    delete env.DEMO_PEGAWAI_PASSWORD;
    delete env.DEMO_PEMILIK_PASSWORD;
    app = spawn(process.execPath, ["--env-file=.env", "dist/index.js"], {
      env, windowsHide: true, stdio: "ignore",
    });
    url = "http://127.0.0.1:" + port + "/api";
    for (let i = 0; i < 80; i++) {
      if (app.exitCode !== null) throw new Error("API uji berhenti sebelum siap.");
      try { if ((await fetch(url + "/health")).ok) return; } catch {}
      await wait(100);
    }
    throw new Error("API uji belum siap.");
  }
  async function stop() {
    if (app && app.exitCode === null && app.signalCode === null) {
      const exited = once(app, "exit");
      app.kill();
      await exited;
    }
  }
  async function http(method, route, expected, token, body) {
    const headers = {};
    if (token) headers.Authorization = "Bearer " + token;
    if (body && !(body instanceof FormData)) {
      headers["Content-Type"] = "application/json";
      body = JSON.stringify(body);
    }
    const result = await fetch(url + route, { method, headers, body, signal: AbortSignal.timeout(10000) });
    assert.equal(result.status, expected, method + " " + route);
    if (result.status === 204) return;
    if (result.headers.get("content-type")?.startsWith("image/")) return Buffer.from(await result.arrayBuffer());
    return result.json();
  }
  try {
    admin("CREATE DATABASE " + schema + " CHARACTER SET utf8mb4;");
    dibuatDB = true;
    const ddl = await fs.readFile("database/01_skema.sql", "utf8");
    const tabel = ddl.indexOf("CREATE TABLE kategori (");
    assert.notEqual(tabel, -1);
    admin("USE " + schema + ";\n" + ddl.slice(tabel));
    const credentials = admin("CREATE USER '" + account + "'@'localhost' IDENTIFIED BY RANDOM PASSWORD;");
    dibuatAkun = true;
    password = credentials.split("\t")[2];
    assert.ok(password);
    for (const table of ["kategori", "barang"]) {
      admin("GRANT SELECT, INSERT, UPDATE, DELETE ON " + schema + "." + table + " TO '" + account + "'@'localhost';");
    }
    process.loadEnvFile(".env.demo");
    await start();
    await t.test("health utama dan login dua role", async () => {
      assert.deepEqual(await http("GET", "/health", 200), { status: "ok", nama_database: "rakrapi" });
      async function login(role, pass) {
        const result = await http("POST", "/auth/login", 200, null, { email: role + ".uji@rakrapi.test", password: pass });
        assert.equal(result.user.role, role);
        return result.token;
      }
      pemilik = await login("pemilik", process.env.DEMO_PEMILIK_PASSWORD);
      pegawai = await login("pegawai", process.env.DEMO_PEGAWAI_PASSWORD);
    });
    await t.test("pemilik CRUD kategori, validasi, dan pembatasan pegawai", async () => {
      assert.deepEqual((await http("GET", "/kategori", 200, pemilik)).data, []);
      const { data } = await http("POST", "/kategori", 201, pemilik, { nama: "Minyak" });
      const item = "/kategori/" + data.id;
      assert.deepEqual((await http("GET", item, 200, pemilik)).data, data);
      await http("POST", "/kategori", 409, pemilik, { nama: "Minyak" });
      await http("POST", "/kategori", 400, pemilik, { nama: "  " });
      assert.equal((await http("PATCH", item, 200, pemilik, { nama: "Minyak Goreng" })).data.nama, "Minyak Goreng");
      for (const [method, route] of [["GET", "/kategori"], ["GET", item], ["POST", "/kategori"], ["PATCH", item], ["DELETE", item]]) {
        await http(method, route, 403, pegawai);
      }
      await http("GET", item, 401);
      await http("DELETE", item, 204, pemilik);
      await http("GET", item, 404, pemilik);
    });
    await t.test("JOIN daftar/detail kedua role dan DELETE kategori terpakai", async () => {
      const cat = (await http("POST", "/kategori", 201, pemilik, { nama: "Kategori uji JOIN" })).data;
      const id = Number(admin("USE " + schema + "; INSERT INTO barang (kategori_id,nama,harga_rupiah,stok,satuan,foto_key) VALUES (" +
        cat.id + ",'Minyak goreng 1 L',19000,12,'botol','uji-join'); SELECT LAST_INSERT_ID();"));
      for (const token of [pegawai, pemilik]) {
        const detail = (await http("GET", "/barang/" + id, 200, token)).data;
        assert.equal(detail.nama_kategori, cat.nama);
        assert.equal(detail.foto_url, "/api/barang/" + id + "/foto");
        assert.deepEqual((await http("GET", "/barang", 200, token)).data, [detail]);
      }
      const conflict = await http("DELETE", "/kategori/" + cat.id, 409, pemilik);
      assert.equal(conflict.pesan, "Kategori ini masih digunakan. Kategori bisa dihapus setelah tidak ada barang yang menggunakannya.");
      assert.equal((await http("GET", "/barang/" + id, 200, pegawai)).data.kategori_id, cat.id);
      admin("DELETE FROM " + schema + ".barang WHERE id=" + id + ";");
      await http("DELETE", "/kategori/" + cat.id, 204, pemilik);
    });
  } finally {
    await stop();
    if (dibuatAkun) admin("DROP USER '" + account + "'@'localhost';");
    if (dibuatDB) admin("DROP DATABASE " + schema + ";");
    const actual = await fs.realpath(folder);
    if (path.dirname(actual) === await fs.realpath(os.tmpdir()) && path.basename(actual).startsWith("rakrapi-foto-")) {
      await fs.rm(actual, { recursive: true });
    }
  }
});
