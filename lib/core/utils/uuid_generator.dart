import 'dart:math';

/// Generator UUID v4 (RFC 4122) murni menggunakan Dart tanpa dependensi eksternal.
/// Memastikan setiap record baru yang di-insert ke tabel Supabase/PostgreSQL
/// memiliki UUID primer yang valid dan tidak melanggar not-null constraint.
class UuidGenerator {
  static final Random _random = Random.secure();

  /// Menghasilkan string UUID v4 acak kriptografis (format: 8-4-4-4-12)
  static String v4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));

    // Versi 4: bit ke-12 s/d 15 dari time_hi_and_version diset ke 0100
    bytes[6] = (bytes[6] & 0x0f) | 0x40;

    // Varian RFC 4122: bit ke-6 dan 7 dari clock_seq_hi_and_reserved diset ke 10
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
