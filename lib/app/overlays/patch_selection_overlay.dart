import 'package:flutter/material.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class PatchSelectionOverlay extends StatefulWidget {
  const PatchSelectionOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  State<PatchSelectionOverlay> createState() => _PatchSelectionOverlayState();
}

final class _PatchSelectionOverlayState extends State<PatchSelectionOverlay> {
  String? _selectedPatchId;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final request = game.pendingPatchSelection;
    if (request == null) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: const Color(0xE603050A),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    game.localization.text('patchSelection.title'),
                    style: const TextStyle(
                      color: Color(0xFFF4F7FF),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    game.localization.text('patchSelection.subtitle'),
                    style: const TextStyle(
                      color: Color(0xFFA9B4C8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: request.choices
                        .map(
                          (patch) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: _PatchCard(
                                game: game,
                                patch: patch,
                                isSelected: _selectedPatchId == patch.id,
                                onSelected: () {
                                  if (_selectedPatchId == patch.id) {
                                    game.selectPatch(patch.id);
                                  } else {
                                    setState(() => _selectedPatchId = patch.id);
                                  }
                                },
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _PatchCard extends StatelessWidget {
  const _PatchCard({
    required this.game,
    required this.patch,
    required this.isSelected,
    required this.onSelected,
  });

  final PatchWorldGame game;
  final PatchDefinition patch;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onSelected,
        child: Container(
          constraints: const BoxConstraints(minHeight: 330),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF36E1FF)
                  : const Color(0xFF35425E),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _localized('risk', patch.riskLabel),
                style: const TextStyle(
                  color: Color(0xFFFFC857),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _localized('title', patch.title),
                style: const TextStyle(
                  color: Color(0xFFF4F7FF),
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 20),
              _CardSection(
                label: game.localization.text('patchSelection.fix'),
                color: const Color(0xFF36E1FF),
                body: _localized('fix', patch.fix),
              ),
              const SizedBox(height: 16),
              _CardSection(
                label: game.localization.text('patchSelection.sideEffect'),
                color: const Color(0xFFFF4FD8),
                body: _localized('sideEffect', patch.sideEffect),
              ),
              const SizedBox(height: 16),
              _CardSection(
                label: game.localization.text('patchSelection.tactic'),
                color: const Color(0xFFFFC857),
                body: _localized('tactic', patch.tactic),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSelected,
                  child: Text(
                    game.localization.text(
                      isSelected
                          ? 'patchSelection.confirm'
                          : 'patchSelection.select',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _localized(String field, String fallback) {
    final value = game.localization.text('${patch.id}.$field');
    return value.startsWith('[') ? fallback : value;
  }
}

final class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.label,
    required this.color,
    required this.body,
  });

  final String label;
  final Color color;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          body,
          style: const TextStyle(
            color: Color(0xFFD7DEEC),
            height: 1.45,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
