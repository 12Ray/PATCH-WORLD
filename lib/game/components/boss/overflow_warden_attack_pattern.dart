import 'package:patch_world/game/components/enemies/platformer/enemy_action_timeline.dart';

final class OverflowWardenAttackSpec {
  const OverflowWardenAttackSpec({
    required this.id,
    required this.telegraphSeconds,
    required this.activeSeconds,
    required this.recoverySeconds,
    required this.attackSpace,
    required this.counterplay,
  });

  final String id;
  final double telegraphSeconds;
  final double activeSeconds;
  final double recoverySeconds;
  final String attackSpace;
  final String counterplay;

  String get fingerprint =>
      '$attackSpace/$counterplay/${telegraphSeconds.toStringAsFixed(2)}/'
      '${activeSeconds.toStringAsFixed(2)}/'
      '${recoverySeconds.toStringAsFixed(2)}';

  EnemyActionTimeline createTimeline() => EnemyActionTimeline(
    id: id,
    telegraphSeconds: telegraphSeconds,
    activeSeconds: activeSeconds,
    recoverySeconds: recoverySeconds,
  );
}

abstract final class OverflowWardenAttackCatalog {
  static const List<OverflowWardenAttackSpec> all = <OverflowWardenAttackSpec>[
    OverflowWardenAttackSpec(
      id: 'shieldSlam',
      telegraphSeconds: .48,
      activeSeconds: .20,
      recoverySeconds: .42,
      attackSpace: 'wide-low-shield-impact',
      counterplay: 'jump-over-the-floor-height-slam',
    ),
    OverflowWardenAttackSpec(
      id: 'overflowGrenade',
      telegraphSeconds: .50,
      activeSeconds: .22,
      recoverySeconds: .52,
      attackSpace: 'single-bounce-ballistic-arc',
      counterplay: 'cross-under-the-apex-and-watch-the-bounce',
    ),
    OverflowWardenAttackSpec(
      id: 'checksumFan',
      telegraphSeconds: .54,
      activeSeconds: .24,
      recoverySeconds: .56,
      attackSpace: 'five-lane-fan-with-gold-center',
      counterplay: 'stand-between-lanes-or-reflect-the-center',
    ),
    OverflowWardenAttackSpec(
      id: 'memoryQuake',
      telegraphSeconds: .82,
      activeSeconds: .30,
      recoverySeconds: .68,
      attackSpace: 'six-alternating-floor-columns',
      counterplay: 'move-into-the-telegraphed-column-gap',
    ),
    OverflowWardenAttackSpec(
      id: 'shieldCharge',
      telegraphSeconds: .62,
      activeSeconds: .28,
      recoverySeconds: .58,
      attackSpace: 'locked-horizontal-shield-lane',
      counterplay: 'jump-the-locked-lane-then-punish-recovery',
    ),
  ];

  /// Phase-local decks keep the encounter readable while expanding its
  /// counterplay vocabulary as containment fails.
  static const Map<int, List<String>> phaseDecks = <int, List<String>>{
    1: <String>['shieldSlam', 'overflowGrenade', 'shieldCharge'],
    2: <String>['shieldSlam', 'overflowGrenade', 'checksumFan', 'shieldCharge'],
    3: <String>[
      'shieldSlam',
      'overflowGrenade',
      'checksumFan',
      'memoryQuake',
      'shieldCharge',
    ],
  };

  static OverflowWardenAttackSpec byId(String id) =>
      all.singleWhere((spec) => spec.id == id);

  static List<String> deckForPhase(int phase) {
    final deck = phaseDecks[phase];
    if (deck == null) throw ArgumentError.value(phase, 'phase');
    return deck;
  }
}

/// Tracks the representative patterns completed during one health phase.
///
/// The Warden cannot skip a phase just because the player reaches its healing
/// threshold quickly: two different counterplay checks must resolve first.
final class OverflowWardenPhaseAttackGate {
  OverflowWardenPhaseAttackGate({this.requiredDistinctAttacks = 2})
    : assert(requiredDistinctAttacks > 0);

  final int requiredDistinctAttacks;
  final Set<String> _completedAttackIds = <String>{};

  int get completedDistinctAttackCount => _completedAttackIds.length;
  bool get isReady => completedDistinctAttackCount >= requiredDistinctAttacks;
  Set<String> get completedAttackIds =>
      Set<String>.unmodifiable(_completedAttackIds);

  void record(String attackId) {
    if (attackId.isNotEmpty) _completedAttackIds.add(attackId);
  }

  void reset() => _completedAttackIds.clear();
}

/// Clamps a horizontal shield charge to the authored arena while keeping the
/// Warden's body clear of both boundary walls.
double resolveOverflowWardenChargeEndX({
  required double startX,
  required double facing,
  required double arenaWidth,
  required double bodyWidth,
  double arenaLeft = 0,
  double? arenaRight,
  double distance = 320,
}) {
  final minimumX = arenaLeft + bodyWidth * .75;
  final authoredMaximumX = (arenaRight ?? arenaWidth) - bodyWidth * .75;
  final maximumX = authoredMaximumX < minimumX ? minimumX : authoredMaximumX;
  final direction = facing < 0 ? -1.0 : 1.0;
  return (startX + direction * distance).clamp(minimumX, maximumX).toDouble();
}

/// Resolves the eight-frame Art v3 contract while preserving the Warden's
/// health-phase idle silhouettes outside an attack.
int resolveOverflowWardenAttackFrame({
  required EnemyActionPhase? actionPhase,
  required double visualClock,
  required int idleFrame,
}) => switch (actionPhase) {
  null || EnemyActionPhase.completed => idleFrame,
  EnemyActionPhase.telegraph => 4,
  EnemyActionPhase.active => 5,
  EnemyActionPhase.recovery =>
    6 + ((visualClock.isFinite ? visualClock : 0) * 10).floor().abs() % 2,
};
