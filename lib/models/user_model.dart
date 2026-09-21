class UserModel {
  const UserModel({
    required this.id,
    required this.mobileNumber,
    this.fullName,
    this.languagePreference = 'hi',
    this.kycStatus = 0,
    this.isAdmin = false,
  });

  final String id;
  final String mobileNumber;
  final String? fullName;
  final String languagePreference;
  final int kycStatus;
  final bool isAdmin;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      mobileNumber: json['mobileNumber'] as String,
      fullName: json['fullName'] as String?,
      languagePreference: json['languagePreference'] as String? ?? 'hi',
      kycStatus: json['kycStatus'] as int? ?? 0,
      isAdmin: json['isAdmin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mobileNumber': mobileNumber,
        'fullName': fullName,
        'languagePreference': languagePreference,
        'kycStatus': kycStatus,
        'isAdmin': isAdmin,
      };
}
