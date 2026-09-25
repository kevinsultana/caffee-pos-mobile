import 'package:flutter/foundation.dart';

@immutable
class StoreSettingsModel {
  final String id;
  final String storeId;
  final int printerWidth; // 58 atau 80 mm
  final bool receiptShowLogo;
  final String? receiptLogoUrl;
  final bool receiptShowStoreName;
  final String? receiptHeader;
  final String receiptHeaderAlign; // 'LEFT', 'CENTER', 'RIGHT'
  final bool receiptHeaderBold;
  final String? receiptFooter;
  final String receiptFooterAlign; // 'LEFT', 'CENTER', 'RIGHT'
  final bool receiptFooterBold;
  final String receiptFontSize; // 'NORMAL', 'SMALL'
  final bool receiptDoubleHeight;
  final int? receiptCols; // null -> otomatis 32 (58mm) atau 48 (80mm)

  const StoreSettingsModel({
    required this.id,
    required this.storeId,
    this.printerWidth = 58,
    this.receiptShowLogo = true,
    this.receiptLogoUrl,
    this.receiptShowStoreName = true,
    this.receiptHeader,
    this.receiptHeaderAlign = 'CENTER',
    this.receiptHeaderBold = false,
    this.receiptFooter =
        'Terima kasih atas kunjungan Anda!\nSimpan struk sebagai bukti pembayaran.',
    this.receiptFooterAlign = 'CENTER',
    this.receiptFooterBold = false,
    this.receiptFontSize = 'NORMAL',
    this.receiptDoubleHeight = true,
    this.receiptCols,
  });

  /// Jumlah kolom efektif untuk format teks ESC/POS
  int get effectiveCols => receiptCols ?? (printerWidth == 80 ? 48 : 32);

  /// Garis pembatas tunggal (-)
  String get separator => '-' * effectiveCols;

  /// Garis pembatas ganda (=)
  String get doubleSeparator => '=' * effectiveCols;

  factory StoreSettingsModel.fromMap(Map<String, dynamic> map) {
    return StoreSettingsModel(
      id: map['id']?.toString() ?? '',
      storeId: map['storeId']?.toString() ?? '',
      printerWidth: (map['printerWidth'] is num)
          ? (map['printerWidth'] as num).toInt()
          : int.tryParse(map['printerWidth']?.toString() ?? '58') ?? 58,
      receiptShowLogo: map['receiptShowLogo'] == null
          ? true
          : (map['receiptShowLogo'] == true ||
              map['receiptShowLogo']?.toString().toLowerCase() == 'true'),
      receiptLogoUrl: map['receiptLogoUrl']?.toString(),
      receiptShowStoreName: map['receiptShowStoreName'] == null
          ? true
          : (map['receiptShowStoreName'] == true ||
              map['receiptShowStoreName']?.toString().toLowerCase() == 'true'),
      receiptHeader: map['receiptHeader']?.toString(),
      receiptHeaderAlign: map['receiptHeaderAlign']?.toString().toUpperCase() ?? 'CENTER',
      receiptHeaderBold: map['receiptHeaderBold'] == true ||
          map['receiptHeaderBold']?.toString().toLowerCase() == 'true',
      receiptFooter: map['receiptFooter']?.toString() ??
          'Terima kasih atas kunjungan Anda!\nSimpan struk sebagai bukti pembayaran.',
      receiptFooterAlign: map['receiptFooterAlign']?.toString().toUpperCase() ?? 'CENTER',
      receiptFooterBold: map['receiptFooterBold'] == true ||
          map['receiptFooterBold']?.toString().toLowerCase() == 'true',
      receiptFontSize: map['receiptFontSize']?.toString().toUpperCase() ?? 'NORMAL',
      receiptDoubleHeight: map['receiptDoubleHeight'] == null
          ? true
          : (map['receiptDoubleHeight'] == true ||
              map['receiptDoubleHeight']?.toString().toLowerCase() == 'true'),
      receiptCols: (map['receiptCols'] is num)
          ? (map['receiptCols'] as num).toInt()
          : int.tryParse(map['receiptCols']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'storeId': storeId,
      'printerWidth': printerWidth,
      'receiptShowLogo': receiptShowLogo,
      'receiptLogoUrl': receiptLogoUrl,
      'receiptShowStoreName': receiptShowStoreName,
      'receiptHeader': receiptHeader,
      'receiptHeaderAlign': receiptHeaderAlign,
      'receiptHeaderBold': receiptHeaderBold,
      'receiptFooter': receiptFooter,
      'receiptFooterAlign': receiptFooterAlign,
      'receiptFooterBold': receiptFooterBold,
      'receiptFontSize': receiptFontSize,
      'receiptDoubleHeight': receiptDoubleHeight,
      'receiptCols': receiptCols,
    };
  }

  StoreSettingsModel copyWith({
    String? id,
    String? storeId,
    int? printerWidth,
    bool? receiptShowLogo,
    String? receiptLogoUrl,
    bool? receiptShowStoreName,
    String? receiptHeader,
    String? receiptHeaderAlign,
    bool? receiptHeaderBold,
    String? receiptFooter,
    String? receiptFooterAlign,
    bool? receiptFooterBold,
    String? receiptFontSize,
    bool? receiptDoubleHeight,
    int? receiptCols,
  }) {
    return StoreSettingsModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      printerWidth: printerWidth ?? this.printerWidth,
      receiptShowLogo: receiptShowLogo ?? this.receiptShowLogo,
      receiptLogoUrl: receiptLogoUrl ?? this.receiptLogoUrl,
      receiptShowStoreName: receiptShowStoreName ?? this.receiptShowStoreName,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptHeaderAlign: receiptHeaderAlign ?? this.receiptHeaderAlign,
      receiptHeaderBold: receiptHeaderBold ?? this.receiptHeaderBold,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      receiptFooterAlign: receiptFooterAlign ?? this.receiptFooterAlign,
      receiptFooterBold: receiptFooterBold ?? this.receiptFooterBold,
      receiptFontSize: receiptFontSize ?? this.receiptFontSize,
      receiptDoubleHeight: receiptDoubleHeight ?? this.receiptDoubleHeight,
      receiptCols: receiptCols ?? this.receiptCols,
    );
  }

  factory StoreSettingsModel.defaultSettings(String storeId) {
    return StoreSettingsModel(
      id: '',
      storeId: storeId,
      printerWidth: 58,
      receiptShowLogo: true,
      receiptShowStoreName: true,
      receiptHeader: '',
      receiptHeaderAlign: 'CENTER',
      receiptHeaderBold: false,
      receiptFooter:
          'Terima kasih atas kunjungan Anda!\nSimpan struk sebagai bukti pembayaran.',
      receiptFooterAlign: 'CENTER',
      receiptFooterBold: false,
      receiptFontSize: 'NORMAL',
      receiptDoubleHeight: true,
      receiptCols: null,
    );
  }
}
