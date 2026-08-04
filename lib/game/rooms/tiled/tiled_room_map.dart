import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/tiled/room_map_validator.dart';
import 'package:patch_world/game/rooms/tiled/room_object_spec.dart';

final class TiledRoomMap extends Component
    with HasGameReference<PatchWorldGame> {
  TiledRoomMap({required this.fileName});

  final String fileName;
  late final TiledComponent mapComponent;
  final List<RoomObjectSpec> _objects = <RoomObjectSpec>[];
  List<RoomObjectSpec> get objects => List.unmodifiable(_objects);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    mapComponent = await TiledComponent.load(
      fileName,
      Vector2.all(32),
      prefix: 'assets/tiles/maps/',
      priority: -50,
    );
    await add(mapComponent);
    _parseObjectLayers();
    RoomMapValidator.validate(_objects);
  }

  List<RoomObjectSpec> allByClass(String objectClass) => _objects
      .where((object) => object.objectClass == objectClass)
      .toList(growable: false);

  void _parseObjectLayers() {
    const layerNames = <String>[
      'Collision',
      'SpawnPoints',
      'Enemies',
      'Interactions',
      'Triggers',
      'Hints',
    ];
    for (final layerName in layerNames) {
      final layer = mapComponent.tileMap.map.layerByName(layerName);
      if (layer is! ObjectGroup) {
        throw FormatException('$fileName layer "$layerName" must be objects.');
      }
      for (final object in layer.objects) {
        final id = object.properties.getValue<String>('id') ?? object.name;
        final properties = <String, Object?>{};
        for (final property in object.properties) {
          properties[property.name] = property.value;
        }
        _objects.add(
          RoomObjectSpec(
            tiledId: object.id,
            id: id,
            objectClass: object.class_,
            position: Vector2(object.x, object.y),
            size: Vector2(object.width, object.height),
            properties: Map.unmodifiable(properties),
          ),
        );
      }
    }
  }
}
