class XiaozhiConfig {
  static const String defaultOtaUrl = 'https://api.tenclass.net/xiaozhi/ota/';

  final String id;
  final String name;
  final String otaUrl;
  final String websocketUrl;
  final String macAddress;
  final String token;

  XiaozhiConfig({
    required this.id,
    required this.name,
    this.otaUrl = defaultOtaUrl,
    required this.websocketUrl,
    required this.macAddress,
    required this.token,
  });

  factory XiaozhiConfig.fromJson(Map<String, dynamic> json) {
    return XiaozhiConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      otaUrl: json['otaUrl'] as String? ?? defaultOtaUrl,
      websocketUrl: json['websocketUrl'] as String? ?? '',
      macAddress: json['macAddress'] as String? ?? '',
      token: json['token'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'otaUrl': otaUrl,
      'websocketUrl': websocketUrl,
      'macAddress': macAddress,
      'token': token,
    };
  }

  XiaozhiConfig copyWith({
    String? id,
    String? name,
    String? otaUrl,
    String? websocketUrl,
    String? macAddress,
    String? token,
  }) {
    return XiaozhiConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      otaUrl: otaUrl ?? this.otaUrl,
      websocketUrl: websocketUrl ?? this.websocketUrl,
      macAddress: macAddress ?? this.macAddress,
      token: token ?? this.token,
    );
  }
}
