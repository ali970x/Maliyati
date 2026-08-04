enum FinanceAccountKind { cash, wallet, card, bank }

enum FinanceAccountScope { personal, shared }

class FinanceAccount {
  const FinanceAccount({
    required this.id,
    required this.name,
    required this.kind,
    required this.scope,
    required this.colorValue,
    this.openingUsd = 0,
    this.openingLbp = 0,
    this.joinCode,
    this.isSystem = false,
  });

  final String id;
  final String name;
  final FinanceAccountKind kind;
  final FinanceAccountScope scope;
  final int colorValue;
  final double openingUsd;
  final double openingLbp;
  final String? joinCode;
  final bool isSystem;

  static const defaults = <FinanceAccount>[
    FinanceAccount(
      id: 'my_wallet',
      name: 'My Wallet',
      kind: FinanceAccountKind.wallet,
      scope: FinanceAccountScope.personal,
      colorValue: 0xFF1478C9,
      isSystem: true,
    ),
    FinanceAccount(
      id: 'wish_money',
      name: 'Whish Money',
      kind: FinanceAccountKind.wallet,
      scope: FinanceAccountScope.personal,
      colorValue: 0xFF159A9C,
      isSystem: true,
    ),
  ];

  FinanceAccount copyWith({
    String? id,
    String? name,
    FinanceAccountKind? kind,
    FinanceAccountScope? scope,
    int? colorValue,
    double? openingUsd,
    double? openingLbp,
    String? joinCode,
    bool? isSystem,
  }) => FinanceAccount(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    scope: scope ?? this.scope,
    colorValue: colorValue ?? this.colorValue,
    openingUsd: openingUsd ?? this.openingUsd,
    openingLbp: openingLbp ?? this.openingLbp,
    joinCode: joinCode ?? this.joinCode,
    isSystem: isSystem ?? this.isSystem,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'scope': scope.name,
    'color': colorValue,
    'openingUsd': openingUsd,
    'openingLbp': openingLbp,
    if (joinCode?.trim().isNotEmpty == true) 'joinCode': joinCode,
    'isSystem': isSystem,
  };

  factory FinanceAccount.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
      final name = '$raw'.trim().toLowerCase();
      return values.firstWhere(
        (value) => value.name.toLowerCase() == name,
        orElse: () => fallback,
      );
    }

    double number(String key) {
      final value = json[key];
      return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    }

    final name = '${json['name'] ?? ''}'.trim();
    return FinanceAccount(
      id: '${json['id'] ?? name.toLowerCase().replaceAll(' ', '_')}'.trim(),
      name: name,
      kind: enumValue(
        FinanceAccountKind.values,
        json['kind'],
        FinanceAccountKind.wallet,
      ),
      scope: enumValue(
        FinanceAccountScope.values,
        json['scope'],
        FinanceAccountScope.personal,
      ),
      colorValue: json['color'] is num
          ? (json['color'] as num).toInt()
          : int.tryParse('${json['color']}') ?? 0xFF1478C9,
      openingUsd: number('openingUsd'),
      openingLbp: number('openingLbp'),
      joinCode: '${json['joinCode'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['joinCode']}'.trim(),
      isSystem: json['isSystem'] == true,
    );
  }
}
