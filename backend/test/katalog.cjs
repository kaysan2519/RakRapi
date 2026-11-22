// Jalankan dari backend: node --env-file=.env --test test/katalog.cjs
const test = require("node:test");
const assert = require("node:assert/strict");
const { randomBytes, randomUUID } = require("node:crypto");
const { spawn, execFileSync } = require("node:child_process");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const net = require("node:net");
const { once } = require("node:events");
const { setTimeout: wait } = require("node:timers/promises");
const bcrypt = require("bcryptjs");

if (process.env.DB_SSL === 'true') {
  throw Error('Tes ini khusus Laragon. Gunakan konfigurasi lokal; jangan menjalankannya pada Aiven.');
}

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
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "rakrapi-foto-"));
  const folder = path.join(root, "db-" + schema);
  let dibuatDB = false, dibuatAkun = false, password, app, url;
  const sandiUji = randomBytes(16).toString("hex");
  const kunciJwtUji = randomBytes(24).toString("hex");
  let pemilik, pegawai;
  async function start() {
    const listener = net.createServer().listen(0, "127.0.0.1");
    await once(listener, "listening");
    const port = listener.address().port;
    await new Promise(resolve => listener.close(resolve));
    const env = { ...process.env, PORT: String(port), HOST: "127.0.0.1", DB_HOST: "127.0.0.1", DB_PORT: "3306",
      DB_NAME: schema, DB_USER: account, DB_PASSWORD: password, DB_SSL: "false", DB_SSL_CA_BASE64: "",
      UPLOAD_DIR: root, JWT_SECRET: kunciJwtUji, JWT_EXPIRES_IN: "1h", BCRYPT_SALT_ROUNDS: "10" };
    app = spawn(process.execPath, ["dist/index.js"], {
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
    const tabel = ddl.indexOf("CREATE TABLE users (");
    assert.notEqual(tabel, -1);
    admin("USE " + schema + ";\n" + ddl.slice(tabel));
    const hashUji = await bcrypt.hash(sandiUji, 10);
    admin("USE " + schema + "; INSERT INTO users (nama,email,password_hash,role) VALUES ('Pemilik Uji','pemilik.uji@rakrapi.test','" + hashUji + "','pemilik'), ('Pegawai Uji','pegawai.uji@rakrapi.test','" + hashUji + "','pegawai');");
    const credentials = admin("CREATE USER '" + account + "'@'localhost' IDENTIFIED BY RANDOM PASSWORD;");
    dibuatAkun = true;
    password = credentials.split("\t")[2];
    assert.ok(password);
    admin("GRANT SELECT, INSERT, UPDATE, DELETE ON " + schema + ".* TO '" + account + "'@'localhost';");
    await start();
    await t.test("health utama dan login dua role", async () => {
      assert.deepEqual(await http("GET", "/health", 200), { status: "ok", nama_database: schema });
      async function login(role, pass) {
        const result = await http("POST", "/auth/login", 200, null, { email: role + ".uji@rakrapi.test", password: pass });
        assert.equal(result.user.role, role);
        return result.token;
      }
      pemilik = await login("pemilik", sandiUji);
      pegawai = await login("pegawai", sandiUji);
    });
    await t.test("pemilik CRUD kategori, validasi, dan pembatasan pegawai", async () => {
      assert.deepEqual((await http("GET", "/kategori", 200, pemilik)).data, []);
      const { data } = await http("POST", "/kategori", 201, pemilik, { nama: "Minyak" });
      const item = "/kategori/" + data.id;
      assert.deepEqual((await http("GET", item, 200, pemilik)).data, data);
      await http("POST", "/kategori", 409, pemilik, { nama: "Minyak" });
      await http("POST", "/kategori", 400, pemilik, { nama: "  " });
      assert.equal((await http("PATCH", item, 200, pemilik, { nama: "Minyak Goreng" })).data.nama, "Minyak Goreng");
      assert.deepEqual((await http("GET", "/kategori", 200, pegawai)).data, [{id:data.id,nama:"Minyak Goreng"}]);
      for (const [method, route] of [["GET", item], ["POST", "/kategori"], ["PATCH", item], ["DELETE", item]]) {
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
    await t.test("unggah, CRUD barang, validasi, kegagalan simpan, dan restart", async () => {
      // Dua gambar asli dibuat di RAM; tidak ada foto uji dalam repo atau katalog utama.
      const draw = `
        Add-Type -AssemblyName System.Drawing
        $bitmap=[Drawing.Bitmap]::new(9,7)
        $bitmap.SetPixel(3,3,[Drawing.Color]::Gold)
        foreach ($format in @([Drawing.Imaging.ImageFormat]::Png,[Drawing.Imaging.ImageFormat]::Jpeg)) {
          $stream=New-Object IO.MemoryStream
          $bitmap.Save($stream,$format)
          [Convert]::ToBase64String($stream.ToArray())
          $stream.Dispose()
        }
        $bitmap.Dispose()`;
      const [png, jpg] = execFileSync("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", draw],
        { windowsHide: true, encoding: "utf8" }).trim().split(/\r?\n/).map(b => Buffer.from(b, "base64"));
      const cat = (await http("POST", "/kategori", 201, pemilik, { nama: "Minyak Goreng" })).data;
      const jenis = { kategori_id: cat.id, nama: "Minyak goreng 1 L", harga_rupiah: 19000, stok: 12, satuan: "botol" };
      function form(fields, bytes, mime = "image/png") {
        const data = new FormData();
        for (const [k, v] of Object.entries(fields)) data.set(k, String(v));
        if (bytes) data.set("foto", new Blob([bytes], { type: mime }), "foto-dari-hp");
        return data;
      }
      const fileList = async () => (await fs.readdir(folder)).sort();
      await http("POST", "/barang", 400, pemilik, jenis);
      await http("POST", "/barang", 415, pemilik, form(jenis, Buffer.from("bukan gambar")));
      await http("POST", "/barang", 415, pemilik, form(jenis, png, "image/jpeg"));
      const rusak = Buffer.concat([png.subarray(0, 8), Buffer.from("rusak"), png.subarray(-12)]);
      await http("POST", "/barang", 415, pemilik, form(jenis, rusak));
      await http("POST", "/barang", 413, pemilik, form(jenis, Buffer.alloc(5 * 1024 * 1024 + 1)));
      await http("POST", "/barang", 400, pemilik, form({ ...jenis, kategori_id: 4294967295 }, png));
      assert.deepEqual(await fileList(), []);
      assert.deepEqual((await http("GET", "/barang", 200, pegawai)).data, []);
      const { data } = await http("POST", "/barang", 201, pegawai, form(jenis, png));
      const item = "/barang/" + data.id;
      const foto = item + "/foto";
      assert.equal(data.nama_kategori, cat.nama);
      assert.deepEqual(await http("GET", foto, 200, pegawai), png);
      await http("GET", foto, 401);
      assert.equal((await http("GET", item, 200, pegawai)).data.nama, jenis.nama);
      assert.equal((await http("GET", "/barang", 200, pegawai)).data.length, 1);
      await http("DELETE", item, 403, pegawai);
      const filesBefore = await fileList();
      assert.equal(filesBefore.length, 1);
      for (const bad of [{ kategori_id: 0 }, { harga_rupiah: -1 }, { harga_rupiah: "1.2" },
          { stok: -1 }, { stok: "1.5" }, { satuan: "liter" }, { satuan: "kg", stok: "1.1234" },
          { foto_key: "terlarang" }, { nama: " " }]) {
        await http("PATCH", item, 400, pemilik, bad);
      }
      await http("PATCH", item, 400, pemilik, form({ kategori_id: 4294967295 }, jpg, "image/jpeg"));
      assert.deepEqual(await fileList(), filesBefore);
      const setelah = (await http("PATCH", item, 200, pegawai, { harga_rupiah: 20000, stok: 10 })).data;
      assert.equal(setelah.harga_rupiah, 20000);
      assert.equal(Number(setelah.stok), 10);
      assert.deepEqual(await fileList(), filesBefore);
      assert.deepEqual(await http("GET", foto, 200, pegawai), png);
      // Simulasi sisa proses terputus setelah menulis file, sebelum INSERT/COMMIT.
      await stop();
      await fs.writeFile(path.join(folder, randomUUID() + ".png"), png);
      await start();
      const fresh = await http("POST", "/auth/login", 200, null,
        { email: "pegawai.uji@rakrapi.test", password: sandiUji });
      assert.deepEqual(await http("GET", foto, 200, fresh.token), png);
      assert.deepEqual((await http("GET", item, 200, fresh.token)).data, setelah);
      assert.deepEqual(await fileList(), filesBefore);
      // Gagal menulis file baru: baris dan foto lama harus tetap utuh.
      const parked = path.join(root, "parked");
      assert.equal(path.dirname(await fs.realpath(folder)), await fs.realpath(root));
      await fs.rename(folder, parked);
      try {
        await fs.writeFile(folder, "uji folder tidak tersedia", { flag: "wx" });
        await http("PATCH", item, 503, pemilik, form({ harga_rupiah: 7 }, jpg, "image/jpeg"));
      } finally {
        await fs.unlink(folder);
        await fs.rename(parked, folder);
      }
      assert.deepEqual((await http("GET", item, 200, pegawai)).data, setelah);
      assert.deepEqual(await http("GET", foto, 200, pegawai), png);
      const kilo = (await http("PATCH", item, 200, pegawai, form({ satuan: "kg", stok: "2,125" }, jpg, "image/jpeg"))).data;
      assert.equal(kilo.stok, "2.125");
      assert.deepEqual(await http("GET", foto, 200, pemilik), jpg);
      assert.equal((await fileList()).length, 1);
      assert.notDeepEqual(await fileList(), filesBefore);
      await http("DELETE", item, 204, pemilik);
      await http("GET", item, 404, pegawai);
      await http("GET", foto, 404, pegawai);
      assert.deepEqual(await fileList(), []);
      await http("DELETE", "/kategori/" + cat.id, 204, pemilik);
    });
    const perangkat = process.env.RAKRAPI_EMULATOR;
    if (perangkat) {
      await t.test("alur katalog melalui layar Android", async () => {
        assert.match(perangkat, /^emulator-\d+$/);
        const port = new URL(url).port;
        const penanda = "QA-" + tag;
        await http("POST", "/kategori", 201, pemilik, { nama: penanda });
        const cwd = path.resolve("../frontend");
        const opsi = { cwd, stdio: "inherit", windowsHide: true };
        const flutter = spawn("cmd.exe", ["/d", "/c", "flutter.bat", "test",
          "integration_test/alur_barang_test.dart", "-d", perangkat, "--no-pub", "--reporter", "expanded",
          "--dart-define=BUKTI_SRS=" + (process.env.RAKRAPI_BUKTI_SRS === "1")], opsi);
        const helper = spawn(process.execPath, ["integration_test/kirim_sesi.cjs", perangkat, port, penanda], opsi);
        const selesaiHelper = once(helper, "exit");
        try {
          assert.equal((await once(flutter, "exit"))[0], 0, "tes tampilan katalog");
          assert.equal((await selesaiHelper)[0], 0, "konfigurasi APK uji");
        } finally {
          if (helper.exitCode === null && helper.signalCode === null) helper.kill();
          const adb = path.join(process.env.LOCALAPPDATA, "Android/Sdk/platform-tools/adb.exe");
          execFileSync(adb, ["-s", perangkat, "reverse", "--remove", "tcp:" + port], {windowsHide: true});
        }
      });
    }
  } finally {
    await stop();
    if (dibuatAkun) admin("DROP USER '" + account + "'@'localhost';");
    if (dibuatDB) admin("DROP DATABASE " + schema + ";");
    const actual = await fs.realpath(root);
    if (path.dirname(actual) === await fs.realpath(os.tmpdir()) && path.basename(actual).startsWith("rakrapi-foto-")) {
      await fs.rm(actual, { recursive: true });
    }
  }
});
