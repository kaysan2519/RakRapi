// Jalankan dari laptop setelah memulai tes integrasi Android.
const { execFileSync } = require('node:child_process');
const path = require('node:path');
const { setTimeout: tunggu } = require('node:timers/promises');

async function main() {
  const [perangkat, nomorPort, penanda] = process.argv.slice(2);
  const portUji = Number(nomorPort);
  if (!perangkat || !Number.isInteger(portUji) || portUji < 1 || portUji > 65535 ||
      portUji === 3000 || !/^QA-[a-f0-9]{16}$/.test(penanda ?? '')) {
    throw Error('Gunakan: node kirim_sesi.cjs ID_PERANGKAT PORT_UJI QA-16digitheksadesimal');
  }
  process.loadEnvFile(path.join(__dirname, '../../backend/.env'));
  const konfigurasi = {
    portUji, penanda,
    pegawai: process.env.DEMO_PEGAWAI_PASSWORD,
    pemilik: process.env.DEMO_PEMILIK_PASSWORD,
  };
  if (!konfigurasi.pegawai || !konfigurasi.pemilik) throw Error('Sandi demo lokal belum diisi.');
  const adb = path.join(process.env.LOCALAPPDATA, 'Android/Sdk/platform-tools/adb.exe');
  const jalankan = (args, input) => execFileSync(adb, ['-s', perangkat, ...args], {
    input, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'], encoding: 'utf8',
  });
  jalankan(['reverse', 'tcp:3000', 'tcp:3000']);
  jalankan(['reverse', 'tcp:' + portUji, 'tcp:' + portUji]);
  const file = 'files/rakrapi-qa';
  for (let i = 0; i < 300; i++) {
    const siap = jalankan(['shell', 'if run-as com.example.rakrapi test -f ' + file + '.json.siap; then echo siap; fi']);
    if (siap.trim() === 'siap') {
      jalankan(['shell', "run-as com.example.rakrapi sh -c 'cat > " + file + ".tmp && mv " +
        file + ".tmp " + file + ".json'"], JSON.stringify(konfigurasi));
      return;
    }
    await tunggu(1000);
  }
  throw Error('APK uji belum meminta konfigurasi.');
}

main().catch(() => { console.error('Gagal mengirim konfigurasi uji. Periksa argumen, ADB, dan APK uji.'); process.exitCode = 1; });
