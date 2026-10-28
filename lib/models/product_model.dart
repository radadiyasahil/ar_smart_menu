import 'business_model.dart';

enum ProductStatus {
  draft(0, 'Draft'),
  submitted(1, 'Submitted'),
  processing(2, 'Processing'),
  review(3, 'Review'),
  live(4, 'Live'),
  paused(5, 'Paused'),
  rejected(6, 'Rejected');

  const ProductStatus(this.value, this.label);
  final int value;
  final String label;

  static ProductStatus fromValue(int value) =>
      ProductStatus.values.firstWhere((e) => e.value == value, orElse: () => draft);
}

enum VegStatus {
  veg(0, 'Veg'),
  nonVeg(1, 'Non-veg'),
  vegan(2, 'Vegan'),
  notApplicable(3, 'N/A');

  const VegStatus(this.value, this.label);
  final int value;
  final String label;

  static VegStatus fromValue(int value) =>
      VegStatus.values.firstWhere((e) => e.value == value, orElse: () => notApplicable);
}

enum ProductCategory {
  starter(0, 'Starter'),
  mainCourse(1, 'Main course'),
  dessert(2, 'Dessert'),
  beverage(3, 'Beverage'),
  bread(4, 'Bread'),
  combo(5, 'Combo'),
  tops(6, 'Tops'),
  bottoms(7, 'Bottoms'),
  ethnic(8, 'Ethnic'),
  western(9, 'Western'),
  accessories(10, 'Accessories'),
  sofa(11, 'Sofa'),
  bed(12, 'Bed'),
  table(13, 'Table'),
  chair(14, 'Chair'),
  storage(15, 'Storage'),
  decor(16, 'Decor'),
  cake(17, 'Cake'),
  pastry(18, 'Pastry'),
  mithai(19, 'Mithai'),
  snack(20, 'Snack'),
  other(99, 'Other');

  const ProductCategory(this.value, this.label);
  final int value;
  final String label;

  static ProductCategory fromValue(int? value) {
    if (value == null) return ProductCategory.other;
    return ProductCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ProductCategory.other,
    );
  }

  static List<ProductCategory> forBusinessType(BusinessType type) {
    switch (type) {
      case BusinessType.restaurant:
      case BusinessType.cafe:
        return const [
          ProductCategory.starter,
          ProductCategory.mainCourse,
          ProductCategory.dessert,
          ProductCategory.beverage,
          ProductCategory.bread,
          ProductCategory.combo,
          ProductCategory.snack,
          ProductCategory.other,
        ];
      case BusinessType.bakery:
        return const [
          ProductCategory.cake,
          ProductCategory.pastry,
          ProductCategory.mithai,
          ProductCategory.bread,
          ProductCategory.beverage,
          ProductCategory.snack,
          ProductCategory.other,
        ];
      case BusinessType.clothing:
        return const [
          ProductCategory.tops,
          ProductCategory.bottoms,
          ProductCategory.ethnic,
          ProductCategory.western,
          ProductCategory.accessories,
          ProductCategory.other,
        ];
      case BusinessType.furniture:
        return const [
          ProductCategory.sofa,
          ProductCategory.bed,
          ProductCategory.table,
          ProductCategory.chair,
          ProductCategory.storage,
          ProductCategory.decor,
          ProductCategory.other,
        ];
    }
  }
}

enum PhotoAngleType {
  front(0, 'Front'),
  top(1, 'Top'),
  left(2, 'Left'),
  right(3, 'Right'),
  back(4, 'Back'),
  angle45Front(5, '45° front'),
  angle45Back(6, '45° back'),
  detail(7, 'Detail'),
  other(99, 'Other');

  const PhotoAngleType(this.value, this.label);
  final int value;
  final String label;

  static PhotoAngleType fromValue(int value) =>
      PhotoAngleType.values.firstWhere(
        (e) => e.value == value,
        orElse: () => PhotoAngleType.other,
      );

  /// Four angles required before backend auto-submits draft → submitted.
  static const List<PhotoAngleType> requiredForSubmit = [
    PhotoAngleType.front,
    PhotoAngleType.top,
    PhotoAngleType.left,
    PhotoAngleType.right,
  ];
}

class ProductPhotoModel {
  const ProductPhotoModel({
    required this.id,
    required this.photoUrl,
    required this.sortOrder,
    this.angleType = PhotoAngleType.other,
  });

  final String id;
  final String photoUrl;
  final int sortOrder;
  final PhotoAngleType angleType;

  factory ProductPhotoModel.fromJson(Map<String, dynamic> json) {
    return ProductPhotoModel(
      id: json['id'] as String,
      photoUrl: json['photoUrl'] as String,
      sortOrder: json['sortOrder'] as int? ?? 0,
      angleType: PhotoAngleType.fromValue(json['angleType'] as int? ?? 99),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'photoUrl': photoUrl,
        'sortOrder': sortOrder,
        'angleType': angleType.value,
      };
}

class ProductModel {
  const ProductModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    this.pricePaise,
    this.category,
    required this.vegStatus,
    this.isSpicy = false,
    this.isBestseller = false,
    this.isNew = false,
    required this.status,
    this.rejectionReason,
    this.soldOutToday = false,
    this.displayOrder = 0,
    this.photos = const [],
    this.createdAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String? description;
  final int? pricePaise;
  final ProductCategory? category;
  final VegStatus vegStatus;
  final bool isSpicy;
  final bool isBestseller;
  final bool isNew;
  final ProductStatus status;
  final String? rejectionReason;
  final bool soldOutToday;
  final int displayOrder;
  final List<ProductPhotoModel> photos;
  final DateTime? createdAt;

  bool get isLive => status == ProductStatus.live;
  bool get isPaused => status == ProductStatus.paused;
  bool get isDraft => status == ProductStatus.draft;
  bool get isSubmitted => status == ProductStatus.submitted;
  bool get isRejected => status == ProductStatus.rejected;
  /// Hero dishes require 4 angle photos and photogrammetry AR processing
  bool get isHero => photos.length >= 4 || isSubmitted || isDraft || status == ProductStatus.processing || status == ProductStatus.review;
  bool get isNormal => !isHero;

  static const String _improvementMarker = '\n\nWhat to improve:\n';

  /// Admin rejection reason (without improvement section).
  String? get rejectionReasonOnly {
    final raw = rejectionReason;
    if (raw == null || raw.isEmpty) return null;
    final idx = raw.indexOf(_improvementMarker);
    if (idx < 0) return raw.trim();
    return raw.substring(0, idx).trim();
  }

  /// Admin guidance on what the owner should improve.
  String? get rejectionImprovementNotes {
    final raw = rejectionReason;
    if (raw == null) return null;
    final idx = raw.indexOf(_improvementMarker);
    if (idx < 0) return null;
    final notes = raw.substring(idx + _improvementMarker.length).trim();
    return notes.isEmpty ? null : notes;
  }

  static const int photosRequiredForSubmit = 4;

  bool get hasAllRequiredAngles {
    final used = photos.map((p) => p.angleType).toSet();
    return PhotoAngleType.requiredForSubmit.every(used.contains);
  }

  /// Upload / replace photos until paused. Live products can replace existing angles.
  bool get canUploadPhotos {
    if (status == ProductStatus.paused) return false;
    if (isLive) return true;
    return !hasAllRequiredAngles;
  }

  int get missingPhotoSlots =>
      PhotoAngleType.requiredForSubmit.where((a) => photoForAngle(a) == null).length;

  PhotoAngleType? get nextSuggestedAngle {
    for (final angle in PhotoAngleType.requiredForSubmit) {
      if (photoForAngle(angle) == null) return angle;
    }
    return null;
  }

  ProductPhotoModel? photoForAngle(PhotoAngleType angle) =>
      requiredSlotPhotos[angle];

  /// Maps photos to Front / Top / Left / Right slots (handles legacy missing angles).
  Map<PhotoAngleType, ProductPhotoModel?> get requiredSlotPhotos {
    final result = <PhotoAngleType, ProductPhotoModel?>{};
    final used = <String>{};

    for (final angle in PhotoAngleType.requiredForSubmit) {
      ProductPhotoModel? match;
      for (final photo in photos) {
        if (photo.angleType == angle && !used.contains(photo.id)) {
          match = photo;
          used.add(photo.id);
          break;
        }
      }
      result[angle] = match;
    }

    final leftovers = photos.where((p) => !used.contains(p.id)).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    var leftoverIndex = 0;
    for (final angle in PhotoAngleType.requiredForSubmit) {
      if (result[angle] != null) continue;
      if (leftoverIndex < leftovers.length) {
        result[angle] = leftovers[leftoverIndex++];
      }
    }

    return result;
  }

  String get priceLabel {
    if (pricePaise == null) return '—';
    return '₹${(pricePaise! / 100).toStringAsFixed(pricePaise! % 100 == 0 ? 0 : 2)}';
  }

  String? get thumbnailUrl =>
      photos.isNotEmpty ? photos.first.photoUrl : null;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final photosJson = json['photos'] as List<dynamic>? ?? [];
    return ProductModel(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      pricePaise: json['pricePaise'] as int?,
      category: json['category'] != null
          ? ProductCategory.fromValue(json['category'] as int)
          : null,
      vegStatus: VegStatus.fromValue(json['vegStatus'] as int? ?? 3),
      isSpicy: json['isSpicy'] as bool? ?? false,
      isBestseller: json['isBestseller'] as bool? ?? false,
      isNew: json['isNew'] as bool? ?? false,
      status: ProductStatus.fromValue(json['status'] as int? ?? 0),
      rejectionReason: json['rejectionReason'] as String?,
      soldOutToday: json['soldOutToday'] as bool? ?? false,
      displayOrder: json['displayOrder'] as int? ?? 0,
      photos: photosJson
          .map((e) => ProductPhotoModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  /// Lightweight JSON for local cache (list views — no photo blobs).
  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'description': description,
        'pricePaise': pricePaise,
        'category': category?.value,
        'vegStatus': vegStatus.value,
        'isSpicy': isSpicy,
        'isBestseller': isBestseller,
        'isNew': isNew,
        'status': status.value,
        'rejectionReason': rejectionReason,
        'soldOutToday': soldOutToday,
        'displayOrder': displayOrder,
        'photos': photos.map((p) => p.toJson()).toList(),
        'createdAt': createdAt?.toIso8601String(),
      };
}
