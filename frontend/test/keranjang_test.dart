import 'package:flutter_test/flutter_test.dart';
import 'package:rakrapi/keranjang.dart';

void main() {
  test(
    'Jumlah dipesan sesuai satuan, subtotal tepat, dan kiriman aman diulangi',
    () {
      expect(jumlahPerseribu('12', 'botol'), 12000);
      expect(jumlahPerseribu('1,5', 'botol'), isNull);
      expect(jumlahPerseribu('0', 'kg'), isNull);
      expect(jumlahPerseribu('-2', 'kg'), isNull);
      expect(jumlahPerseribu('1.2345', 'kg'), isNull);
      expect(jumlahPerseribu('2,125', 'kg'), 2125);
      final keranjang = Keranjang();
      final beras = {'id': 1, 'harga_rupiah': 1500};
      keranjang.atur(beras, 2125);
      expect(keranjang.item[1]!.subtotal, BigInt.from(3188));
      final kunci = keranjang.kunciKirim;
      expect(keranjang.kunciKirim, kunci);
      keranjang.atur(beras, 2000);
      expect(keranjang.kunciKirim, isNot(kunci));
      keranjang.atur(beras, 0);
      expect(keranjang.item, isEmpty);
    },
  );
}
