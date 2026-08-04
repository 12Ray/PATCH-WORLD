import 'package:flutter/material.dart';
import 'package:patch_world/game/core/run_metrics.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/services/build_info.dart';

final class EndingOverlay extends StatelessWidget {
  const EndingOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xF2080B14),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ValueListenableBuilder<RunSummary?>(
          valueListenable: game.completedRun,
          builder: (context, summary, _) => summary == null
              ? _EndingChoice(game: game)
              : _RunSummaryView(game: game, summary: summary),
        ),
      ),
    ),
  );
}

final class _EndingChoice extends StatelessWidget {
  const _EndingChoice({required this.game});
  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 700),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          'ACTIVE HUMAN PLAYERS: 1',
          style: TextStyle(
            color: Color(0xFF36E1FF),
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          game.localization.text('ending.final'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF4F7FF),
            fontSize: 29,
            height: 1.35,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          game.localization.text('ending.choose'),
          style: const TextStyle(color: Color(0xFFA9B4C8)),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: <Widget>[
            FilledButton(
              onPressed: () => game.chooseEnding('preserve'),
              child: Text(game.localization.text('ending.preserve')),
            ),
            OutlinedButton(
              onPressed: () => game.chooseEnding('purge'),
              child: Text(game.localization.text('ending.purge')),
            ),
          ],
        ),
      ],
    ),
  );
}

final class _RunSummaryView extends StatelessWidget {
  const _RunSummaryView({required this.game, required this.summary});
  final PatchWorldGame game;
  final RunSummary summary;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 620),
    child: Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              game.localization.text('summary.title'),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            _stat(
              game.localization.text('summary.time'),
              summary.formattedTime,
            ),
            _stat(
              game.localization.text('summary.deaths'),
              '${summary.deaths}',
            ),
            _stat(
              game.localization.text('summary.damage'),
              '${summary.damageTaken}',
            ),
            _stat(
              game.localization.text('summary.overflows'),
              '${summary.overflowCount}',
            ),
            _stat(
              game.localization.text('summary.patches'),
              summary.selectedPatchIds
                  .map((id) {
                    final title = game.localization.text('$id.title');
                    return title.startsWith('[') ? id.split('.').last : title;
                  })
                  .join(', '),
            ),
            _stat(
              game.localization.text('summary.ending'),
              game.localization.text('ending.${summary.endingId}'),
            ),
            const Divider(height: 26),
            _stat(game.localization.text('summary.score'), '${summary.score}'),
            _stat(game.localization.text('summary.best'), '${game.bestScore}'),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: <Widget>[
                FilledButton(
                  onPressed: game.restartRun,
                  child: Text(game.localization.text('summary.again')),
                ),
                OutlinedButton(
                  onPressed: game.returnToTitle,
                  child: Text(game.localization.text('summary.titleScreen')),
                ),
                OutlinedButton(
                  onPressed: game.openCreditsFromEnding,
                  child: Text(game.localization.text('ui.credits')),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              BuildInfo.label,
              style: const TextStyle(color: Color(0xFF6F7D96), fontSize: 10),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _stat(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFFA9B4C8))),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}
