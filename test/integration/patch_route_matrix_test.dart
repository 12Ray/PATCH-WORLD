import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/rules/rule_ids.dart';

void main() {
  test('generates exactly eight unique patch routes', () {
    const roomOne = <String>[RuleIds.motionTax, RuleIds.retaliationEcho];
    const roomTwo = <String>[RuleIds.hostileTurbo, RuleIds.frameBurst];
    const roomThree = <String>[RuleIds.phaseLeak, RuleIds.duplicateFault];
    final routes = <String>{};
    for (final first in roomOne) {
      for (final second in roomTwo) {
        for (final third in roomThree) {
          routes.add('$first|$second|$third');
        }
      }
    }
    expect(routes, hasLength(8));
  });
}
