class AppSettings {
  final List<String> blacklistedTags;
  final String defaultDurationFilter; // 'all', 'gt2min', 'gt5min', 'gt10min', 'custom'
  final double customMinDuration;
  final String r34UserId;
  final String r34ApiKey;
  final String gelbooruUserId;
  final String gelbooruApiKey;
  final String booruSource; // 'rule34', 'realbooru', 'gelbooru', 'tbib', 'safebooru'
  final bool enableDoh;
  final String dohProvider; // 'cloudflare', 'google', 'adguard', 'custom'
  final String customDohUrl;
  final bool enableProxy;
  final String proxyHost;
  final int proxyPort;
  final bool autoPlay;
  final double defaultPlaybackSpeed;
  final bool muteByDefault;
  final String language; // 'ru' or 'en'

  AppSettings({
    List<String>? blacklistedTags,
    this.defaultDurationFilter = 'gt2min',
    this.customMinDuration = 120.0,
    this.r34UserId = '',
    this.r34ApiKey = '',
    this.gelbooruUserId = '',
    this.gelbooruApiKey = '',
    this.booruSource = 'rule34',
    this.enableDoh = false,
    this.dohProvider = 'cloudflare',
    this.customDohUrl = '',
    this.enableProxy = false,
    this.proxyHost = '',
    this.proxyPort = 8080,
    this.autoPlay = true,
    this.defaultPlaybackSpeed = 1.0,
    this.muteByDefault = false,
    this.language = 'ru',
  }) : blacklistedTags = blacklistedTags ?? [
          'guro',
          'scat',
        ];

  Map<String, dynamic> toJson() {
    return {
      'blacklistedTags': blacklistedTags,
      'defaultDurationFilter': defaultDurationFilter,
      'customMinDuration': customMinDuration,
      'r34UserId': r34UserId,
      'r34ApiKey': r34ApiKey,
      'gelbooruUserId': gelbooruUserId,
      'gelbooruApiKey': gelbooruApiKey,
      'booruSource': booruSource,
      'enableDoh': enableDoh,
      'dohProvider': dohProvider,
      'customDohUrl': customDohUrl,
      'enableProxy': enableProxy,
      'proxyHost': proxyHost,
      'proxyPort': proxyPort,
      'autoPlay': autoPlay,
      'defaultPlaybackSpeed': defaultPlaybackSpeed,
      'muteByDefault': muteByDefault,
      'language': language,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    List<String> list = [];
    if (json['blacklistedTags'] is List) {
      list = (json['blacklistedTags'] as List).map((e) => e.toString()).toList();
    }
    return AppSettings(
      blacklistedTags: list.isNotEmpty ? list : ['guro', 'scat'],
      defaultDurationFilter: json['defaultDurationFilter'] ?? 'gt2min',
      customMinDuration: (json['customMinDuration'] as num?)?.toDouble() ?? 120.0,
      r34UserId: json['r34UserId']?.toString() ?? '',
      r34ApiKey: json['r34ApiKey']?.toString() ?? '',
      gelbooruUserId: json['gelbooruUserId']?.toString() ?? '',
      gelbooruApiKey: json['gelbooruApiKey']?.toString() ?? '',
      booruSource: json['booruSource']?.toString() ?? 'rule34',
      enableDoh: json['enableDoh'] == true,
      dohProvider: json['dohProvider'] ?? 'cloudflare',
      customDohUrl: json['customDohUrl'] ?? '',
      enableProxy: json['enableProxy'] == true,
      proxyHost: json['proxyHost'] ?? '',
      proxyPort: json['proxyPort'] is int ? json['proxyPort'] : 8080,
      autoPlay: json['autoPlay'] ?? true,
      defaultPlaybackSpeed: (json['defaultPlaybackSpeed'] as num?)?.toDouble() ?? 1.0,
      muteByDefault: json['muteByDefault'] == true,
      language: json['language']?.toString() ?? 'ru',
    );
  }

  AppSettings copyWith({
    List<String>? blacklistedTags,
    String? defaultDurationFilter,
    double? customMinDuration,
    String? r34UserId,
    String? r34ApiKey,
    String? gelbooruUserId,
    String? gelbooruApiKey,
    String? booruSource,
    bool? enableDoh,
    String? dohProvider,
    String? customDohUrl,
    bool? enableProxy,
    String? proxyHost,
    int? proxyPort,
    bool? autoPlay,
    double? defaultPlaybackSpeed,
    bool? muteByDefault,
    String? language,
  }) {
    return AppSettings(
      blacklistedTags: blacklistedTags ?? List.from(this.blacklistedTags),
      defaultDurationFilter: defaultDurationFilter ?? this.defaultDurationFilter,
      customMinDuration: customMinDuration ?? this.customMinDuration,
      r34UserId: r34UserId ?? this.r34UserId,
      r34ApiKey: r34ApiKey ?? this.r34ApiKey,
      gelbooruUserId: gelbooruUserId ?? this.gelbooruUserId,
      gelbooruApiKey: gelbooruApiKey ?? this.gelbooruApiKey,
      booruSource: booruSource ?? this.booruSource,
      enableDoh: enableDoh ?? this.enableDoh,
      dohProvider: dohProvider ?? this.dohProvider,
      customDohUrl: customDohUrl ?? this.customDohUrl,
      enableProxy: enableProxy ?? this.enableProxy,
      proxyHost: proxyHost ?? this.proxyHost,
      proxyPort: proxyPort ?? this.proxyPort,
      autoPlay: autoPlay ?? this.autoPlay,
      defaultPlaybackSpeed: defaultPlaybackSpeed ?? this.defaultPlaybackSpeed,
      muteByDefault: muteByDefault ?? this.muteByDefault,
      language: language ?? this.language,
    );
  }
}
