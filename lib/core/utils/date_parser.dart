/// Helper untuk mem-parsing timestamp dari Supabase PostgreSQL secara akurat.
///
/// Karena PostgreSQL menyimpan timestamp dalam UTC (CURRENT_TIMESTAMP) pada kolom
/// 'timestamp without time zone', Supabase sering mengembalikan string tanpa akhiran 'Z'
/// (misal: '2026-09-23T10:41:21.059').
/// Fungsi ini memastikan timestamp tersebut diinterpretasikan sebagai UTC lalu dikonversi
/// ke waktu lokal perangkat pengguna (.toLocal()), mencegah bug double timezone / lompat +7 jam.
DateTime parseDateTime(dynamic raw) {
  if (raw == null) return DateTime.now();
  if (raw is DateTime) return raw.toLocal();
  final str = raw.toString().trim();
  if (str.isEmpty) return DateTime.now();

  // Jika string sudah memiliki penanda UTC ('Z') atau offset (+07:00 / -05:00)
  if (str.endsWith('Z') || RegExp(r'[+-]\d{2}(:\d{2})?$').hasMatch(str)) {
    return (DateTime.tryParse(str) ?? DateTime.now()).toLocal();
  }

  // Jika formatnya '2026-09-23 10:41:21' (ada spasi), ganti dengan 'T'
  final isoFormatted = str.replaceFirst(' ', 'T');

  // Anggap sebagai UTC dan konversi ke waktu lokal HP
  final asUtc = DateTime.tryParse('${isoFormatted}Z');
  if (asUtc != null) {
    return asUtc.toLocal();
  }

  return (DateTime.tryParse(isoFormatted) ?? DateTime.now()).toLocal();
}

DateTime? tryParseDateTime(dynamic raw) {
  if (raw == null) return null;
  final str = raw.toString().trim();
  if (str.isEmpty || str == 'null') return null;
  return parseDateTime(raw);
}
