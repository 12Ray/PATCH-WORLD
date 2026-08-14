enum RunItemId {
  conduitHeart,
  overflowCapacitor,
  echoClock,
  temporalRelay,
  vectorBoots,
  collisionPrism,
  dashBuffer,
  airStack,
  targetingDaemon,
}

extension RunItemIdPresentation on RunItemId {
  String get localizationKey => 'item.$name.name';
  String get descriptionLocalizationKey => 'item.$name.description';
}

/// Items collected during the current campaign run.
final class RunItemState {
  final Set<RunItemId> _items = <RunItemId>{};

  Set<RunItemId> get items => Set<RunItemId>.unmodifiable(_items);
  bool contains(RunItemId item) => _items.contains(item);
  bool acquire(RunItemId item) => _items.add(item);

  void reset() => _items.clear();
}
