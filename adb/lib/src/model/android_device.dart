/// Androidデバイス情報
class AndroidDevice {
  final String serialId;
  final String brand;
  final String model;

  String get deviceName => '$brand $model';

  const AndroidDevice({
    required this.serialId,
    required this.brand,
    required this.model,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AndroidDevice &&
          runtimeType == other.runtimeType &&
          serialId == other.serialId &&
          brand == other.brand &&
          model == other.model;

  @override
  int get hashCode => serialId.hashCode ^ brand.hashCode ^ model.hashCode;

  @override
  String toString() {
    return 'AndroidDevice{serialId: $serialId, brand: $brand, model: $model}';
  }
}
