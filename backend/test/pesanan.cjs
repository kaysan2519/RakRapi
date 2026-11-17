const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');

async function ujiPesanan({api,pemilik,pegawai,warga,password,sql}) {
  async function http(method, path, token, body, status) {
    const multipart = body instanceof FormData;
    const headers = {Authorization: 'Bearer ' + token};
    if (!multipart) headers['Content-Type']='application/json';
    const res=await fetch(api+path,{method,headers,body:multipart ? body : JSON.stringify(body)});
    const json=await res.json();
    assert.equal(res.status,status,method+' '+path+' '+(json.pesan || ''));
    return json.data ?? json;
  }
  const kategori=await http('POST','/kategori',pemilik,{nama:'Sembako demo'},201);
  const foto=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAO0lEQVR4nO3RQREAMAjEwKNCq7laUFAJ4cMvK+CYCdXvZtNZXY8HBvwBMhEyETIRMhEyETIRMhEyUcgHUgkCYJsgX6IAAAAASUVORK5CYII=','base64');
  async function barang(nama,harga,stok,satuan) {
    const data=new FormData();
    for(const [k,v] of Object.entries({nama,harga_rupiah:harga,stok,satuan,kategori_id:kategori.id})) data.set(k,String(v));
    data.set('foto',new Blob([foto],{type:'image/png'}),'fixture.png');
    return (await http('POST','/barang',pemilik,data,201)).id;
  }
  const minyak=await barang('Minyak goreng 1 L',19000,14,'botol');
  const beras=await barang('Beras medium',14000,'12.500','kg');
  const stok=()=>sql('SELECT stok FROM barang ORDER BY id').split(/\r?\n/);
  const order=(a,b)=>({kunci_kirim:randomBytes(16).toString('hex'),item:[{barang_id:minyak,jumlah:a},{barang_id:beras,jumlah:b}]});
  const akun={nama:'Warga uji API',email:'warga.transaksi@rakrapi.test',password};
  await http('POST','/auth/register','',akun,201);
  const lain=(await http('POST','/auth/login','',{email:akun.email,password},200)).token;
  for(const body of [order('1.5',1),order(0,1),order(-1,1),order(1,'0.0001')]) {
    await http('POST','/pesanan',lain,body,400);
  }
  const gagal=await http('POST','/pesanan',lain,order(1,999),201);
  const awal=stok();
  const tolak=await http('PATCH','/pesanan/'+gagal.id+'/konfirmasi',pegawai,undefined,409);
  assert.match(tolak.pesan,/Beras medium/);
  assert.deepEqual(stok(),awal);
  assert.equal((await http('GET','/pesanan/'+gagal.id,lain,undefined,200)).status,'Menunggu konfirmasi');
  const body=order(2,'2,500');
  const [p,ulang]=await Promise.all([http('POST','/pesanan',lain,body,201),http('POST','/pesanan',lain,body,201)]);
  assert.equal(p.id,ulang.id);
  assert.deepEqual(stok(),awal);
  await http('PATCH','/barang/'+minyak,pemilik,{harga_rupiah:20000},200);
  const lama=await http('GET','/pesanan/'+p.id,lain,undefined,200);
  assert.equal(lama.item[0].harga_rupiah,19000);
  assert.equal(lama.total_rupiah,'73000');
  await http('GET','/pesanan/'+p.id,warga,undefined,404);
  assert.deepEqual(await http('GET','/pesanan',warga,undefined,200),[]);
  await http('PATCH','/pesanan/'+p.id+'/konfirmasi',warga,undefined,403);
  await http('POST','/pesanan',pegawai,body,403);
  const konfirmasi=token=>http('PATCH','/pesanan/'+p.id+'/konfirmasi',token,undefined,200);
  const hasil=await Promise.all([konfirmasi(pemilik),konfirmasi(pegawai)]);
  assert.ok(hasil.every(h=>h.status==='Dikonfirmasi'));
  await konfirmasi(pegawai);
  assert.deepEqual(stok(),['12.000','10.000']);
  await http('PATCH','/barang/'+minyak,pemilik,{harga_rupiah:19000},200);
  console.log('HTTP lulus. Kirim 201; stok saat kirim '+awal.join('/')+'; dua petugas serentak dan satu pengulangan 200, stok akhir '+stok().join('/')+'. Stok kurang 409 (Beras medium), rollback utuh. Lintas warga 404, konfirmasi warga 403, jumlah invalid 400. Harga lama Rp19.000 dan total Rp73.000.');
}
module.exports={ujiPesanan};
