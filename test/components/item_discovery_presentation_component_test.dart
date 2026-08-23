import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/presentation/item_discovery_presentation_component.dart';
import 'package:patch_world/game/items/run_item_state.dart';

void main() {
  test('new loadout installs use the dedicated event presentation tier', () {
    final presentation = ItemDiscoveryPresentationComponent(
      result: const RunItemAcquisitionResult(
        item: RunItemId.afterimageGovernor,
        outcome: RunItemAcquisitionOutcome.installed,
      ),
      rewardTier: ItemRewardTier.loadoutEvent,
    );

    expect(presentation.item, RunItemId.afterimageGovernor);
    expect(presentation.tierLocalizationKey, 'itemDiscovery.loadoutEvent');
  });

  test('duplicate results override every source with a truthful heading', () {
    for (final tier in ItemRewardTier.values) {
      final presentation = ItemDiscoveryPresentationComponent(
        result: const RunItemAcquisitionResult(
          item: RunItemId.prismBore,
          outcome: RunItemAcquisitionOutcome.duplicateConverted,
        ),
        rewardTier: tier,
      );

      expect(
        presentation.tierLocalizationKey,
        'itemDiscovery.duplicateConverted',
      );
    }
  });
}
