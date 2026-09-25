/// Utilitas normalisasi nomor telepon selaras dengan sistem Web POS.
/// Mengubah nomor HP menjadi format standar nasional (08xxxxxxxxxx)
/// dengan membersihkan karakter non-angka dan mengubah awalan 62 atau +62 menjadi 0.
String? normalizePhone(String? phone) {
  if (phone == null) return null;
  String digits = phone.trim().replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('62')) {
    digits = '0${digits.substring(2)}';
  } else if (!digits.startsWith('0')) {
    digits = '0$digits';
  }
  return digits;
}
