import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class CampaignMapOverlay extends StatelessWidget {
  const CampaignMapOverlay({required this.game, super.key});

  final PatchWorldGame game;

  @override
  Widget build(BuildContext context) {
    final exploration = game.campaignExploration;
    return ColoredBox(
      color: const Color(0xE6050811),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860, maxHeight: 480),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xF20B1020),
                border: Border.all(color: const Color(0xFF9DEFFF), width: 2),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x6636E1FF), blurRadius: 28),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.route, color: Color(0xFF9DEFFF)),
                        const SizedBox(width: 10),
                        Text(
                          game.localization.text('map.title'),
                          style: const TextStyle(
                            color: Color(0xFFF4F7FF),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          game.localization.text(
                            'map.discoveredCount',
                            parameters: <String, Object>{
                              'visited': exploration.visitedNodeIds.length,
                              'revealed': exploration.revealedNodeIds.length,
                            },
                          ),
                          style: const TextStyle(
                            color: Color(0xFFA9B4C8),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: game.localization.text('common.close'),
                          onPressed: game.closeCampaignMap,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Semantics(
                        label: game.localization.text('map.title'),
                        child: CustomPaint(
                          key: const Key('campaign-map-canvas'),
                          painter: _CampaignMapPainter(
                            graph: game.campaignWorld,
                            revealed: exploration.revealedNodeIds,
                            visited: exploration.visitedNodeIds,
                            current: exploration.currentNode,
                            checkpoint: exploration.checkpointNodeId,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: <Widget>[
                        _LegendDot(
                          color: const Color(0xFF45F3A6),
                          label: game.localization.text('map.current'),
                        ),
                        _LegendDot(
                          color: const Color(0xFF36E1FF),
                          label: game.localization.text('map.visited'),
                        ),
                        _LegendDot(
                          color: const Color(0xFF56627A),
                          label: game.localization.text('map.revealed'),
                        ),
                        _LegendDot(
                          color: const Color(0xFFFFD35A),
                          label: game.localization.text('map.checkpoint'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 9),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Color(0xFFA9B4C8))),
      ],
    ),
  );
}

final class _CampaignMapPainter extends CustomPainter {
  const _CampaignMapPainter({
    required this.graph,
    required this.revealed,
    required this.visited,
    required this.current,
    required this.checkpoint,
  });

  final CampaignWorldGraph graph;
  final Set<CampaignNodeId> revealed;
  final Set<CampaignNodeId> visited;
  final CampaignNodeId? current;
  final CampaignNodeId? checkpoint;

  @override
  void paint(Canvas canvas, Size size) {
    if (revealed.isEmpty) return;
    final definitions = graph.nodes.values
        .where((node) => revealed.contains(node.id))
        .toList(growable: false);
    final xs = definitions.map((node) => node.mapX);
    final ys = definitions.map((node) => node.mapY);
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    const margin = 52.0;
    Offset pointFor(CampaignNodeDefinition node) {
      final xSpan = (maxX - minX).clamp(1, 100);
      final ySpan = (maxY - minY).clamp(1, 100);
      return Offset(
        margin + (node.mapX - minX) / xSpan * (size.width - margin * 2),
        margin + (node.mapY - minY) / ySpan * (size.height - margin * 2),
      );
    }

    final routePaint = Paint()
      ..color = const Color(0x665D7397)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final connection in graph.connections) {
      if (!revealed.contains(connection.from) ||
          !revealed.contains(connection.to)) {
        continue;
      }
      canvas.drawLine(
        pointFor(graph.nodes[connection.from]!),
        pointFor(graph.nodes[connection.to]!),
        routePaint,
      );
    }

    for (final node in definitions) {
      final center = pointFor(node);
      final isCurrent = current == node.id;
      final isCheckpoint = checkpoint == node.id;
      final isVisited = visited.contains(node.id);
      final color = isCurrent
          ? const Color(0xFF45F3A6)
          : isVisited
          ? const Color(0xFF36E1FF)
          : const Color(0xFF56627A);
      final rect = Rect.fromCenter(
        center: center,
        width: node.kind == CampaignNodeKind.boss ? 58 : 46,
        height: node.kind == CampaignNodeKind.secret ? 24 : 30,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = color.withValues(alpha: isVisited ? .34 : .12)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = isCurrent ? 3 : 2,
      );
      if (isCheckpoint) {
        canvas.drawCircle(
          center + const Offset(0, -24),
          6,
          Paint()..color = const Color(0xFFFFD35A),
        );
      }
      final label = _mapLabel(node.id);
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isVisited
                ? const Color(0xFFF4F7FF)
                : const Color(0xFF8B96AA),
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: 100);
      textPainter.paint(
        canvas,
        center + Offset(-textPainter.width / 2, rect.height / 2 + 5),
      );
    }
  }

  String _mapLabel(CampaignNodeId id) => id.name
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .toUpperCase();

  @override
  bool shouldRepaint(covariant _CampaignMapPainter oldDelegate) =>
      oldDelegate.current != current ||
      oldDelegate.checkpoint != checkpoint ||
      oldDelegate.revealed.length != revealed.length ||
      oldDelegate.visited.length != visited.length;
}
