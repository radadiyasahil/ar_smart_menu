class QrCodeModel {
  const QrCodeModel({
    required this.id,
    required this.businessId,
    this.productId,
    this.productName,
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
  final String slug;
  final String webUrl;
  final String? qrImageUrl;
  final bool isActive;
  final DateTime? createdAt;

  factory QrCodeModel.fromJson(Map<String, dynamic> json) {
    return QrCodeModel(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      productId: json['productId'] as String?,
      productName: json['productName'] as String?,
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
