class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.timezone,
    required this.currencyCode,
    required this.idealHourlyRateCents,
    required this.status,
  });

  final String id;
  final String username;
  final String displayName;
  final String timezone;
  final String currencyCode;
  final int idealHourlyRateCents;
  final String status;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      timezone: json['timezone'] as String? ?? 'Asia/Shanghai',
      currencyCode: json['currency_code'] as String? ?? 'CNY',
      idealHourlyRateCents:
          (json['ideal_hourly_rate_cents'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
    );
  }
}
