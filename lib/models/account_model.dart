class AccountModel {
  final String id;
  final String name;
  final String type; // e.g., 'Visa', 'Cash', 'Bank'
  final double balance;
  final String currency;
  final bool isDefault;

  AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.currency = 'USD',
    this.isDefault = false,
  });

  factory AccountModel.fromMap(Map<String, dynamic> map, String id) {
    return AccountModel(
      id: id,
      name: map['name'] ?? '',
      type: map['type'] ?? 'Cash',
      balance: _safeConvertAmount(map['balance']),
      currency: map['currency'] ?? 'USD',
      isDefault: map['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'balance': balance,
      'currency': currency,
      'isDefault': isDefault,
    };
  }

  static double _safeConvertAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is int) return amount.toDouble();
    if (amount is double) return amount;
    if (amount is String) return double.tryParse(amount) ?? 0.0;
    return 0.0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
