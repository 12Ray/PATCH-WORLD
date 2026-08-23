import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/items/campaign_loadout_reward_catalog.dart';
import 'package:patch_world/game/items/run_item_state.dart';

void main() {
  test('every chapter and weapon owns one unique loadout-event reward', () {
    expect(
      CampaignLoadoutRewardCatalog.rewards,
      hasLength(
        CampaignLoadoutEventId.values.length * PlayerWeapon.values.length,
      ),
    );

    final itemIds = CampaignLoadoutRewardCatalog.rewards
        .map((reward) => reward.item)
        .toSet();
    expect(itemIds, hasLength(CampaignLoadoutRewardCatalog.rewards.length));

    for (final eventId in CampaignLoadoutEventId.values) {
      for (final weapon in PlayerWeapon.values) {
        final reward = CampaignLoadoutRewardCatalog.forEvent(eventId, weapon);
        expect(reward.eventId, eventId);
        expect(reward.weapon, weapon);
        expect(itemIds, contains(reward.item));
      }
    }
  });

  test('loadout events never reuse mandatory, boss, or secret rewards', () {
    const otherCampaignRewards = <RunItemId>{
      RunItemId.conduitHeart,
      RunItemId.overflowCapacitor,
      RunItemId.echoClock,
      RunItemId.temporalRelay,
      RunItemId.vectorBoots,
      RunItemId.collisionPrism,
      RunItemId.dashBuffer,
      RunItemId.airStack,
      RunItemId.targetingDaemon,
      RunItemId.chronalBuffer,
      RunItemId.echoSpring,
      RunItemId.predictiveScope,
      RunItemId.vectorEdge,
      RunItemId.impactLattice,
      RunItemId.splitChamber,
    };
    final eventRewards = CampaignLoadoutRewardCatalog.rewards
        .map((reward) => reward.item)
        .toSet();

    expect(eventRewards.intersection(otherCampaignRewards), isEmpty);
  });
}
