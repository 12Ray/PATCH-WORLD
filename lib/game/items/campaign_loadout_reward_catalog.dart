import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/items/run_item_state.dart';

enum CampaignLoadoutEventId { damageLab, temporalHall, collisionArchive }

final class CampaignLoadoutRewardSpec {
  const CampaignLoadoutRewardSpec({
    required this.eventId,
    required this.weapon,
    required this.item,
  });

  final CampaignLoadoutEventId eventId;
  final PlayerWeapon weapon;
  final RunItemId item;
}

/// One authoritative mapping for every chapter loadout event.
///
/// Event items intentionally do not overlap mandatory, boss, or optional
/// secret-route rewards. A player who explores before resolving a terminal
/// therefore receives both authored rewards instead of an accidental
/// duplicate conversion.
abstract final class CampaignLoadoutRewardCatalog {
  static const List<CampaignLoadoutRewardSpec> rewards =
      <CampaignLoadoutRewardSpec>[
        CampaignLoadoutRewardSpec(
          eventId: CampaignLoadoutEventId.damageLab,
          weapon: PlayerWeapon.sword,
          item: RunItemId.bladeCalibrator,
        ),
        CampaignLoadoutRewardSpec(
          eventId: CampaignLoadoutEventId.damageLab,
          weapon: PlayerWeapon.gauntlet,
          item: RunItemId.impactCalibrator,
        ),
        CampaignLoadoutRewardSpec(
          eventId: CampaignLoadoutEventId.damageLab,
          weapon: PlayerWeapon.gun,
          item: RunItemId.barrelCalibrator,
        ),
        CampaignLoadoutRewardSpec(
          eventId: CampaignLoadoutEventId.temporalHall,
          weapon: PlayerWeapon.sword,
          item: RunItemId.afterimageGovernor,
        ),
        CampaignLoadoutRewardSpec(
          eventId: CampaignLoadoutEventId.temporalHall,
          weapon: PlayerWeapon.gauntlet,
          item: RunItemId.echoLiftServo,
        ),
        CampaignLoadoutRewardSpec(
          eventId: CampaignLoadoutEventId.temporalHall,
          weapon: PlayerWeapon.gun,
          item: RunItemId.forecastTrigger,
        ),
        CampaignLoadoutRewardSpec(
          eventId: CampaignLoadoutEventId.collisionArchive,
          weapon: PlayerWeapon.sword,
          item: RunItemId.momentumEdge,
        ),
        CampaignLoadoutRewardSpec(
          eventId: CampaignLoadoutEventId.collisionArchive,
          weapon: PlayerWeapon.gauntlet,
          item: RunItemId.seismicCoupler,
        ),
        CampaignLoadoutRewardSpec(
          eventId: CampaignLoadoutEventId.collisionArchive,
          weapon: PlayerWeapon.gun,
          item: RunItemId.prismBore,
        ),
      ];

  static CampaignLoadoutRewardSpec forEvent(
    CampaignLoadoutEventId eventId,
    PlayerWeapon weapon,
  ) => rewards.singleWhere(
    (reward) => reward.eventId == eventId && reward.weapon == weapon,
  );

  static RunItemId rewardFor(
    CampaignLoadoutEventId eventId,
    PlayerWeapon weapon,
  ) => forEvent(eventId, weapon).item;
}
