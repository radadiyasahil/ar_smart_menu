class QrCodeModel {
  const QrCodeModel({
    required this.id,
    required this.businessId,
    this.productId,
    this.productName,
    this.qrType = 0,
    required this.slug,
    required this.webUrl,
    this.qrImageUrl,
    required this.isActive,
    this.createdAt,
  });

  final String id;
  final String businessId;
  final String? productId;
  final String? productName;
  final int qrType;
  final String slug;
  final String webUrl;
  final String? qrImageUrl;
  final bool isActive;
  final DateTime? createdAt;

  bool get isMenu => qrType == 2;
  bool get isTable => qrType == 1;
  bool get isProduct => qrType == 0;

  factory QrCodeModel.fromJson(Map<String, dynamic> json) {
    return QrCodeModel(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      productId: json['productId'] as String?,
      productName: json['productName'] as String?,
      qrType: json['qrType'] as int? ?? 0,
      slug: json['slug'] as String,
      webUrl: json['webUrl'] as String,
      qrImageUrl: json['qrImageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}
