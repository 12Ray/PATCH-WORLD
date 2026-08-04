import 'package:flame/components.dart';

final class RoomObjectSpec {
  const RoomObjectSpec({
    required this.tiledId,
    required this.id,
    required this.objectClass,
    required this.position,
    required this.size,
    required this.properties,
  });

  final int tiledId;
  final String id;
  final String objectClass;
  final Vector2 position;
  final Vector2 size;
  final Map<String, Object?> properties;

  Vector2 get center => position + size / 2;

  String requireString(String key) {
    final value = properties[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Object $id requires String property "$key".');
    }
    return value;
  }

  int requireInt(String key) {
    final value = properties[key];
    if (value is! int) {
      throw FormatException('Object $id requires int property "$key".');
    }
    return value;
  }
}
