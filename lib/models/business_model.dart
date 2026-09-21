enum BusinessType {
  restaurant(0, 'Restaurant'),
  cafe(1, 'Café'),
  bakery(2, 'Bakery'),
  clothing(3, 'Clothing'),
  furniture(4, 'Furniture');

  const BusinessType(this.value, this.label);
  final int value;
  final String label;

  static BusinessType fromValue(int value) =>
      BusinessType.values.firstWhere((e) => e.value == value, orElse: () => restaurant);
}

enum BusinessStatus {
  pendingApproval(0, 'Pending approval'),
  active(1, 'Active'),
  suspended(2, 'Suspended'),
  rejected(3, 'Rejected');

  const BusinessStatus(this.value, this.label);
  final int value;
  final String label;

  static BusinessStatus fromValue(int value) =>
      BusinessStatus.values.firstWhere((e) => e.value == value, orElse: () => pendingApproval);
}

class BusinessModel {
  const BusinessModel({
    required this.id,
    required this.ownerId,
    required this.businessName,
    required this.businessType,
    required this.city,
    required this.fullAddress,
    required this.status,
    this.logoUrl,
    this.fssaiNumber,
    this.gstNumber,
    this.bankAccountNumber,
    this.bankIfsc,
    this.upiId,
    this.bankPennyVerified = false,
    this.rejectionReason,
    this.approvedAt,
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final String businessName;
  final BusinessType businessType;
  final String city;
  final String fullAddress;
  final BusinessStatus status;
  final String? logoUrl;
  final String? fssaiNumber;
  final String? gstNumber;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? upiId;
  final bool bankPennyVerified;
  final String? rejectionReason;
  final DateTime? approvedAt;
  final DateTime? createdAt;

  bool get isPending => status == BusinessStatus.pendingApproval;
  bool get isActive => status == BusinessStatus.active;
  bool get isRejected => status == BusinessStatus.rejected;

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      businessName: json['businessName'] as String,
      businessType: BusinessType.fromValue(json['businessType'] as int? ?? 0),
      city: json['city'] as String,
      fullAddress: json['fullAddress'] as String,
      status: BusinessStatus.fromValue(json['status'] as int? ?? 0),
      logoUrl: json['logoUrl'] as String?,
      fssaiNumber: json['fssaiNumber'] as String?,
      gstNumber: json['gstNumber'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      bankIfsc: json['bankIfsc'] as String?,
      upiId: json['upiId'] as String?,
      bankPennyVerified: json['bankPennyVerified'] as bool? ?? false,
      rejectionReason: json['rejectionReason'] as String?,
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  factory BusinessModel.fromSummaryJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['id'] as String,
      ownerId: '',
      businessName: json['businessName'] as String,
      businessType: BusinessType.fromValue(json['businessType'] as int? ?? 0),
      city: json['city'] as String,
      fullAddress: '',
      status: BusinessStatus.fromValue(json['status'] as int? ?? 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'businessName': businessName,
        'businessType': businessType.value,
        'city': city,
        'fullAddress': fullAddress,
        'status': status.value,
        'logoUrl': logoUrl,
        'fssaiNumber': fssaiNumber,
        'gstNumber': gstNumber,
        'bankAccountNumber': bankAccountNumber,
        'bankIfsc': bankIfsc,
        'upiId': upiId,
        'bankPennyVerified': bankPennyVerified,
        'rejectionReason': rejectionReason,
        'approvedAt': approvedAt?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
      };
}
