// Dari backend: node --env-file=.env test/akun.cjs [ID_EMULATOR]
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const net = require('node:net');
const { once } = require('node:events');
const { randomBytes } = require('node:crypto');
const { execFileSync, spawn } = require('node:child_process');
const { setTimeout: tunggu } = require('node:timers/promises');
const readline = require('node:readline');
const bcrypt = require('bcryptjs');

const cli = process.env.MYSQL_CLI || 'C:/laragon/bin/mysql/mysql-8.0.30-winx64/bin/mysql.exe';
const tag = randomBytes(8).toString('hex');
const db = 'rakrapi_uji_akun_' + tag;
const publik = 'pub_' + tag;
const staf = 'staf_' + tag;
const katalog = 'kat_' + tag;
const emailPemilik = 'pemilik.' + tag + '@rakrapi.test';
const sandi = () => randomBytes(18).toString('hex');

function admin(sql, database) {
  const args = ['--login-path=rakrapi', '--host=127.0.0.1', '--port=3306', '--batch', '--raw', '--skip-column-names'];
  if (database) args.push('--database=' + database);
  try {
    return execFileSync(cli, args, { input: sql, encoding: 'utf8', windowsHide: true, stdio: ['pipe','pipe','pipe'] }).trimEnd();
  } catch (error) {
    const kode = String(error.stderr).match(/ERROR \d+/)?.[0];
    throw Error('SQL uji gagal: ' + (kode || 'koneksi'));
  }
}

async function ujiAndroid(device, port, password) {
  assert.match(device, /^emulator-\d+$/);
  const adb = path.join(process.env.LOCALAPPDATA, 'Android/Sdk/platform-tools/adb.exe');
  const target = 'files/rakrapi-uji-akun-' + tag;
  const run = (args, input) => execFileSync(adb, ['-s', device, ...args], { input, encoding: 'utf8', windowsHide: true });
  run(['reverse', 'tcp:' + port, 'tcp:' + port]);
  const flutter = spawn('cmd.exe', ['/d', '/c', 'flutter.bat', 'test', 'integration_test/akun_test.dart',
    '-d', device, '--no-pub', '--reporter', 'expanded', '--dart-define=KODE_UJI=' + tag], {
    cwd: path.resolve('../frontend'), windowsHide: true, stdio: 'inherit',
  });
  const selesai = once(flutter, 'exit');
  try {
    for (let i = 0; i < 600 && flutter.exitCode === null; i++) {
      if (run(['shell', 'if run-as com.example.rakrapi test -f ' + target + '.siap 2>/dev/null; then echo siap; fi']).trim() === 'siap') {
        // Hanya APK debug uji dapat membaca file privat ini.
        run(['shell', "run-as com.example.rakrapi sh -c 'cat > " + target + ".tmp && mv " + target + ".tmp " + target + "'"],
          JSON.stringify({ port, emailPemilik, password, sandiBaru: sandi() }));
        break;
      }
      await tunggu(1000);
    }
    assert.equal((await selesai)[0], 0, 'tes emulator');
  } finally {
    run(['reverse', '--remove', 'tcp:' + port]);
  }
}

async function main() {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'rakrapi-akun-'));
  let server, dibuat = false;
  const akunUji = [];
  function akunMysql(user) {
    const result = admin("CREATE USER '" + user + "'@'localhost' IDENTIFIED BY RANDOM PASSWORD;");
    akunUji.push(user);
    return result.split('\t')[2];
  }
  try {
    admin('CREATE DATABASE ' + db + ' CHARACTER SET utf8mb4;');
    dibuat = true;
    const skema = fs.readFileSync('database/01_skema.sql', 'utf8');
    const mula = skema.indexOf('CREATE TABLE users (');
    assert.ok(mula > 0 && !/\bUSE\s+/i.test(skema.slice(mula)));
    admin(skema.slice(mula), db);
    const password = sandi();
    const hash = await bcrypt.hash(password, 10);
    admin("INSERT INTO users(nama,email,password_hash,role) VALUES ('Pemilik uji','" + emailPemilik + "','" + hash +
      "','pemilik'), ('Pegawai lama','lama@rakrapi.test','" + hash + "','pegawai');", db);
    const snapshot = () => admin('SELECT id,role,password_hash FROM users ORDER BY id', db);
    const sebelum = snapshot();
    admin(fs.readFileSync('database/03_role_warga.sql', 'utf8'), db);
    admin(fs.readFileSync('database/04_prosedur_pegawai.sql', 'utf8'), db);
    assert.ok(snapshot() === sebelum, 'ID, role dan hash lama harus identik');

    const sandiPublik = akunMysql(publik);
    const sandiStaf = akunMysql(staf);
    const sandiKatalog = akunMysql(katalog);
    admin("GRANT SELECT (id,nama,email,password_hash,role), INSERT (nama,email,password_hash) ON " + db + ".users TO '" + publik + "'@'localhost';");
    const demoManual = process.argv[2] === '--demo';
    const izinKatalog = demoManual ? 'SELECT, INSERT, UPDATE, DELETE' : 'SELECT';
    for (const tabel of ['kategori','barang']) admin("GRANT " + izinKatalog + " ON " + db + "." + tabel + " TO '" + katalog + "'@'localhost';");
    admin("GRANT EXECUTE ON PROCEDURE " + db + ".tambah_pegawai TO '" + staf + "'@'localhost';");
    const listener = net.createServer().listen(0, '127.0.0.1');
    await once(listener, 'listening');
    const port = listener.address().port;
    await new Promise(resolve => listener.close(resolve));
    server = spawn(process.execPath, ['--env-file=.env', 'dist/index.js'], { windowsHide: true, stdio: 'ignore',
      env: { ...process.env, PORT: String(port), AUTH_DB_NAME: db, AUTH_DB_USER: publik, AUTH_DB_PASSWORD: sandiPublik,
        PEGAWAI_DB_USER: staf, PEGAWAI_DB_PASSWORD: sandiStaf, CATALOG_DB_NAME: db, CATALOG_DB_USER: katalog,
        CATALOG_DB_PASSWORD: sandiKatalog, UPLOAD_DIR: folder, JWT_SECRET: sandi() } });
    const api = 'http://127.0.0.1:' + port + '/api';
    for (let i=0; i<100; i++) {
      try { if ((await fetch(api + '/health')).ok) break; } catch {}
      await tunggu(150);
    }
    async function http(metode, rute, status, token, body) {
      const headers = { 'Content-Type':'application/json' };
      if (token) headers.Authorization = 'Bearer ' + token;
      const res = await fetch(api + rute, { method: metode, headers, body: JSON.stringify(body) });
      assert.equal(res.status, status, metode + ' ' + rute);
      const data = await res.json();
      assert.ok(!JSON.stringify(data).includes('password_hash'));
      return data;
    }
    async function login(email) {
      return (await http('POST','/auth/login',200,null,{email,password})).token;
    }
    const pemilik = await login(emailPemilik);
    const lama = await login('lama@rakrapi.test');
    const orang = {nama:'Warga HTTP', email:'warga@rakrapi.test', password, role:'pemilik'};
    assert.equal((await http('POST','/auth/register',201,null,orang)).user.role,'warga');
    await http('POST','/auth/register',409,null,orang);
    const warga = await login(orang.email);
    assert.equal((await http('GET','/auth/me',200,warga)).user.role,'warga');
    for (const rute of ['/barang','/barang/2','/barang/2/foto','/kategori']) await http('GET',rute,403,warga);
    const calon = {...orang,email:'baru@rakrapi.test'};
    await http('POST','/auth/pegawai',401,null,calon);
    for (const token of [warga,lama]) await http('POST','/auth/pegawai',403,token,calon);
    assert.equal((await http('POST','/auth/pegawai',201,pemilik,calon)).user.role,'pegawai');
    await http('POST','/auth/pegawai',409,pemilik,calon);
    const pegawai = await login(calon.email);
    assert.equal((await http('GET','/auth/me',200,pegawai)).user.role,'pegawai');
    await http('GET','/barang',200,pegawai);
    const hashBaru = admin("SELECT password_hash FROM users WHERE email='warga@rakrapi.test'", db);
    assert.ok(await bcrypt.compare(password, hashBaru));
    console.log('Lulus: migration menjaga akun lama; register 201 warga; duplikat 409; katalog warga 403; tambah pegawai 401/403/201; login dan hash benar.');
    if (demoManual) {
      const panduan = path.join(folder, 'akun-demo.txt');
      fs.writeFileSync(panduan, [
        'Akun sementara, hanya untuk API demo pada port ' + port,
        'Pemilik: ' + emailPemilik, 'Pegawai: baru@rakrapi.test', 'Warga: warga@rakrapi.test',
        'Sandi untuk ketiga akun: ' + password,
      ].join(os.EOL), { mode: 0o600, flag: 'wx' });
      console.log('Email dan sandi ada di file lokal ' + panduan);
      console.log('Di terminal frontend, jalankan:');
      console.log('& "$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" -s emulator-5554 reverse tcp:' + port + ' tcp:' + port);
      console.log('flutter.bat run -d emulator-5554 --no-pub --dart-define=API_URL=http://127.0.0.1:' + port + '/api');
      console.log('Tekan Enter di terminal ini sesudah demo untuk membersihkan data sementara.');
      const input = readline.createInterface({input:process.stdin,output:process.stdout});
      const berhenti = () => input.close();
      const tutup = once(input, 'close');
      input.once('line', berhenti);
      input.once('SIGINT', berhenti);
      process.once('SIGTERM', berhenti);
      await tutup;
      process.off('SIGTERM', berhenti);
    } else if (process.argv[2]) {
      await ujiAndroid(process.argv[2],port,password);
    }
  } finally {
    if (server && server.exitCode === null && server.signalCode === null) {
      const berhenti=once(server,'exit'); server.kill(); await berhenti;
    }
    if (dibuat) admin('DROP DATABASE ' + db);
    for (const user of akunUji) admin("DROP USER '" + user + "'@'localhost'");
    if (path.dirname(folder) === os.tmpdir() && path.basename(folder).startsWith('rakrapi-akun-')) {
      fs.rmSync(folder,{recursive:true,force:true});
    }
  }
}
main().catch(error => { console.error(error.message); process.exitCode=1; });
