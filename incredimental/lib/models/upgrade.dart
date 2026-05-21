class Upgrade {
  final int id;
  final String name;
  final String target;
  final BigInt cost;
  final double multiplier;

  Upgrade({
    required this.id,
    required this.name,
    required this.target,
    required this.cost,
    required this.multiplier,
  });

  /// Factory constructor to create Upgrade from JSON map.
  /// Converts the 'cost' field from String to BigInt.
  factory Upgrade.fromJson(Map<String, dynamic> json) {
    return Upgrade(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] as String,
      target: json['target'] as String,
      cost: BigInt.parse(json['cost'].toString()),
      multiplier: (json['multiplier'] as num).toDouble(),
    );
  }

  @override
  String toString() => 'Upgrade(id=$id, name=$name, target=$target, cost=$cost, multiplier=$multiplier)';
}
