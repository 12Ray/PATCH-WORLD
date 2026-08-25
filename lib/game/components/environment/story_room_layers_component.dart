import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';

/// Story-only visual families. Gameplay collision geometry is intentionally
/// owned by the room builder rather than this decorative component.
enum StoryRegionVisualTheme { boot, damage, temporal, collision, optimizer }

/// A reusable visual identity for each kind of story room.
enum StoryRoomVisualMotif {
  hub,
  intake,
  assembly,
  overflow,
  boss,
  dashSecret,
  verticalSecret,
  rangedSecret,
  ascent,
  fracture,
  pendulum,
  compression,
  merge,
  finalCore,
}

/// Rendering order is part of the map-art contract.
enum StoryRoomVisualLayer { far, middle, foreground }

/// A code-native, 32 px modular backdrop for story rooms.
///
/// The component draws decoration only. In particular, it never draws a long,
/// horizontal top edge that could be mistaken for a collidable platform.
final class StoryRoomLayersComponent extends PositionComponent {
  StoryRoomLayersComponent({
    required this.theme,
    required this.motif,
    required Vector2 worldSize,
  }) : assert(worldSize.x > 0 && worldSize.y > 0),
       super(size: worldSize.clone(), priority: -120);

  static const double moduleSize = 32;
  static const String farBackgroundAsset =
      'assets/images/rooms/story-machine-void-far-v1.png';
  static const List<StoryRoomVisualLayer> layerOrder = <StoryRoomVisualLayer>[
    StoryRoomVisualLayer.far,
    StoryRoomVisualLayer.middle,
    StoryRoomVisualLayer.foreground,
  ];

  final StoryRegionVisualTheme theme;
  final StoryRoomVisualMotif motif;
  Image? _farBackgroundImage;
  Picture? _cachedPicture;
  bool _removed = false;

  bool get hasFarBackgroundImage => _farBackgroundImage != null;
  bool get hasCachedPicture => _cachedPicture != null;

  _StoryPalette get _palette => _paletteFor(theme);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _removed = false;
    _rebuildPictureCache();
    unawaited(_loadFarBackground());
  }

  Future<void> _loadFarBackground() async {
    try {
      final data = await rootBundle.load(farBackgroundAsset);
      final codec = await instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      late final Image image;
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (_removed) {
        image.dispose();
        return;
      }
      _farBackgroundImage?.dispose();
      _farBackgroundImage = image;
      _rebuildPictureCache();
    } catch (_) {
      // Procedural layers remain a deterministic fallback for missing assets.
    }
  }

  @override
  void onRemove() {
    _removed = true;
    _cachedPicture?.dispose();
    _cachedPicture = null;
    _farBackgroundImage?.dispose();
    _farBackgroundImage = null;
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    if (_removed) return;
    _cachedPicture ??= _recordPicture();
    canvas.drawPicture(_cachedPicture!);
  }

  void _rebuildPictureCache() {
    if (_removed) return;
    final next = _recordPicture();
    _cachedPicture?.dispose();
    _cachedPicture = next;
  }

  Picture _recordPicture() {
    final recorder = PictureRecorder();
    _renderLayers(Canvas(recorder));
    return recorder.endRecording();
  }

  void _renderLayers(Canvas canvas) {
    canvas.save();
    canvas.clipRect(size.toRect());
    for (final layer in layerOrder) {
      renderLayer(canvas, layer);
    }
    canvas.restore();
  }

  /// Kept public so visual-regression tooling can inspect layers separately.
  void renderLayer(Canvas canvas, StoryRoomVisualLayer layer) {
    switch (layer) {
      case StoryRoomVisualLayer.far:
        _renderFarLayer(canvas);
      case StoryRoomVisualLayer.middle:
        _renderMiddleLayer(canvas);
      case StoryRoomVisualLayer.foreground:
        _renderForegroundLayer(canvas);
    }
  }

  void _renderFarLayer(Canvas canvas) {
    final palette = _palette;
    final bounds = size.toRect();
    canvas.drawRect(bounds, Paint()..color = palette.voidColor);
    final farImage = _farBackgroundImage;
    if (farImage != null) {
      canvas.drawImageRect(
        farImage,
        Rect.fromLTWH(
          0,
          0,
          farImage.width.toDouble(),
          farImage.height.toDouble(),
        ),
        bounds,
        Paint()
          ..filterQuality = FilterQuality.none
          ..color = const Color.fromRGBO(255, 255, 255, .42),
      );
    }
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = Gradient.radial(
          Offset(size.x * .52, size.y * .43),
          math.max(size.x, size.y) * .72,
          <Color>[
            palette.fog.withValues(alpha: .40),
            palette.voidColor.withValues(alpha: .06),
            const Color(0xCC030508),
          ],
          const <double>[0, .58, 1],
        ),
    );

    _drawModularDust(canvas, palette);
    _drawFarArchitecture(canvas, palette);
  }

  void _drawModularDust(Canvas canvas, _StoryPalette palette) {
    final columns = (size.x / moduleSize).ceil();
    final rows = (size.y / moduleSize).ceil();
    final paint = Paint()..color = palette.structure.withValues(alpha: .12);
    for (var row = 1; row < rows; row += 1) {
      for (var column = 1; column < columns; column += 1) {
        if ((row * 7 + column * 11 + theme.index * 3) % 9 != 0) continue;
        final radius = (row + column).isEven ? 1.1 : .7;
        canvas.drawCircle(
          Offset(column * moduleSize, row * moduleSize),
          radius,
          paint,
        );
      }
    }
  }

  void _drawFarArchitecture(Canvas canvas, _StoryPalette palette) {
    final pillarPaint = Paint()
      ..color = palette.structure.withValues(alpha: .13);
    final seamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = palette.highlight.withValues(alpha: .08);
    final columns = math.max(3, (size.x / (moduleSize * 8)).floor());
    for (var index = 0; index <= columns; index += 1) {
      final x = _snap(
        (index + .55) * size.x / math.max(1, columns),
        moduleSize,
      );
      final width = moduleSize * (index.isEven ? 2 : 1);
      final fromCeiling = (index + theme.index).isEven;
      final extent = moduleSize * (5 + (index * 3 + theme.index) % 8);
      final rect = fromCeiling
          ? Rect.fromLTWH(x, -moduleSize, width, extent)
          : Rect.fromLTWH(
              x,
              math.max(moduleSize, size.y - extent + moduleSize),
              width,
              extent,
            );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        pillarPaint,
      );
      canvas.drawLine(
        Offset(rect.center.dx, rect.top + moduleSize),
        Offset(rect.center.dx, rect.bottom - moduleSize),
        seamPaint,
      );
    }
  }

  void _renderMiddleLayer(Canvas canvas) {
    final palette = _palette;
    switch (theme) {
      case StoryRegionVisualTheme.boot:
        _drawBootMachinery(canvas, palette);
      case StoryRegionVisualTheme.damage:
        _drawDamageMachinery(canvas, palette);
      case StoryRegionVisualTheme.temporal:
        _drawTemporalMachinery(canvas, palette);
      case StoryRegionVisualTheme.collision:
        _drawCollisionMachinery(canvas, palette);
      case StoryRegionVisualTheme.optimizer:
        _drawOptimizerMachinery(canvas, palette);
    }
    _drawMotif(canvas, palette);
  }

  void _drawBootMachinery(Canvas canvas, _StoryPalette palette) {
    final paint = _stroke(palette.highlight, .17, 2);
    final center = Offset(_snap(size.x * .5), _snap(size.y * .42));
    for (var ring = 0; ring < 3; ring += 1) {
      canvas.drawCircle(center, moduleSize * (2 + ring * 1.35), paint);
    }
    for (final direction in const <double>[-1, 1]) {
      final x = _snap(size.x * (.5 + direction * .27));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, center.dy),
            width: moduleSize * 1.5,
            height: moduleSize * 7,
          ),
          const Radius.circular(12),
        ),
        paint,
      );
    }
  }

  void _drawDamageMachinery(Canvas canvas, _StoryPalette palette) {
    final pipePaint = _stroke(palette.highlight, .18, 3);
    for (var index = 0; index < 4; index += 1) {
      final x = _snap(size.x * (.16 + index * .23));
      final bend = moduleSize * (index.isEven ? 2 : -2);
      final path = Path()
        ..moveTo(x, -moduleSize)
        ..cubicTo(
          x,
          size.y * .22,
          x + bend,
          size.y * .30,
          x + bend,
          size.y * .48,
        )
        ..cubicTo(
          x + bend,
          size.y * .62,
          x,
          size.y * .72,
          x,
          size.y + moduleSize,
        );
      canvas.drawPath(path, pipePaint);
      canvas.drawCircle(
        Offset(x + bend, _snap(size.y * .48)),
        moduleSize * .55,
        _stroke(palette.accent, .22, 2),
      );
    }
  }

  void _drawTemporalMachinery(Canvas canvas, _StoryPalette palette) {
    final centers = <Offset>[
      Offset(_snap(size.x * .28), _snap(size.y * .38)),
      Offset(_snap(size.x * .72), _snap(size.y * .54)),
    ];
    for (var clock = 0; clock < centers.length; clock += 1) {
      final center = centers[clock];
      final radius = moduleSize * (clock == 0 ? 3.2 : 2.4);
      canvas.drawCircle(center, radius, _stroke(palette.highlight, .16, 2));
      canvas.drawCircle(
        center,
        radius - moduleSize * .45,
        _stroke(palette.structure, .22, 1),
      );
      for (var tick = 0; tick < 12; tick += 1) {
        final angle = tick * math.pi / 6;
        final direction = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          center + direction * (radius - 7),
          center + direction * radius,
          _stroke(palette.accent, .18, 1.5),
        );
      }
    }
  }

  void _drawCollisionMachinery(Canvas canvas, _StoryPalette palette) {
    final paint = _stroke(palette.highlight, .16, 2);
    final columns = math.max(3, (size.x / (moduleSize * 7)).floor());
    for (var index = 0; index < columns; index += 1) {
      final center = Offset(
        _snap((index + .5) * size.x / columns),
        _snap(size.y * (.30 + (index % 3) * .16)),
      );
      final radius = moduleSize * (1.4 + (index % 2) * .6);
      final diamond = Path()
        ..moveTo(center.dx, center.dy - radius)
        ..lineTo(center.dx + radius, center.dy)
        ..lineTo(center.dx, center.dy + radius)
        ..lineTo(center.dx - radius, center.dy)
        ..close();
      canvas.drawPath(diamond, paint);
      canvas.drawCircle(
        center,
        moduleSize * .28,
        Paint()..color = palette.accent.withValues(alpha: .16),
      );
    }
  }

  void _drawOptimizerMachinery(Canvas canvas, _StoryPalette palette) {
    final center = Offset(_snap(size.x * .5), _snap(size.y * .46));
    final maximum = math.min(size.x, size.y) * .36;
    for (var ring = 0; ring < 7; ring += 1) {
      final radius = maximum * ((ring + 1) / 7);
      canvas.drawCircle(
        center,
        radius,
        _stroke(
          ring.isEven ? palette.highlight : palette.structure,
          ring.isEven ? .18 : .12,
          ring % 3 == 0 ? 2 : 1,
        ),
      );
    }
  }

  void _drawMotif(Canvas canvas, _StoryPalette palette) {
    switch (motif) {
      case StoryRoomVisualMotif.hub:
        _drawHubMotif(canvas, palette);
      case StoryRoomVisualMotif.intake:
        _drawIntakeMotif(canvas, palette);
      case StoryRoomVisualMotif.assembly:
        _drawAssemblyMotif(canvas, palette);
      case StoryRoomVisualMotif.overflow:
        _drawOverflowMotif(canvas, palette);
      case StoryRoomVisualMotif.boss:
        _drawBossMotif(canvas, palette);
      case StoryRoomVisualMotif.dashSecret:
        _drawDashSecretMotif(canvas, palette);
      case StoryRoomVisualMotif.verticalSecret:
        _drawVerticalSecretMotif(canvas, palette);
      case StoryRoomVisualMotif.rangedSecret:
        _drawRangedSecretMotif(canvas, palette);
      case StoryRoomVisualMotif.ascent:
        _drawAscentMotif(canvas, palette);
      case StoryRoomVisualMotif.fracture:
        _drawFractureMotif(canvas, palette);
      case StoryRoomVisualMotif.pendulum:
        _drawPendulumMotif(canvas, palette);
      case StoryRoomVisualMotif.compression:
        _drawCompressionMotif(canvas, palette);
      case StoryRoomVisualMotif.merge:
        _drawMergeMotif(canvas, palette);
      case StoryRoomVisualMotif.finalCore:
        _drawFinalCoreMotif(canvas, palette);
    }
  }

  void _drawHubMotif(Canvas canvas, _StoryPalette palette) {
    final center = Offset(_snap(size.x * .5), _snap(size.y * .5));
    canvas.drawCircle(
      center,
      moduleSize * 1.25,
      _stroke(palette.accent, .24, 3),
    );
    for (var index = 0; index < 6; index += 1) {
      final angle = index * math.pi / 3 + math.pi / 6;
      final node =
          center + Offset(math.cos(angle), math.sin(angle)) * moduleSize * 3;
      canvas.drawCircle(
        node,
        5,
        Paint()..color = palette.accent.withValues(alpha: .24),
      );
    }
  }

  void _drawIntakeMotif(Canvas canvas, _StoryPalette palette) {
    final paint = Paint()..color = palette.accent.withValues(alpha: .15);
    for (var index = 0; index < 5; index += 1) {
      final center = Offset(
        _snap(size.x * (.18 + index * .16)),
        _snap(size.y * (.24 + (index % 2) * .18)),
      );
      canvas.drawPath(_downChevron(center, moduleSize * .55), paint);
    }
  }

  void _drawAssemblyMotif(Canvas canvas, _StoryPalette palette) {
    final paint = _stroke(palette.accent, .20, 2);
    for (var index = 0; index < 4; index += 1) {
      final x = _snap(size.x * (.2 + index * .2));
      final joint = Offset(x, _snap(size.y * (.28 + (index % 2) * .20)));
      canvas.drawLine(Offset(x, 0), joint, paint);
      canvas.drawCircle(joint, moduleSize * .45, paint);
      canvas.drawLine(
        joint,
        joint + Offset(index.isEven ? moduleSize : -moduleSize, moduleSize),
        paint,
      );
    }
  }

  void _drawOverflowMotif(Canvas canvas, _StoryPalette palette) {
    final fill = Paint()..color = palette.accent.withValues(alpha: .12);
    for (var index = 0; index < 12; index += 1) {
      final x = _snap(size.x * ((index + 1) / 13));
      final y = _snap(size.y * (.18 + ((index * 7) % 9) / 13));
      canvas.drawCircle(
        Offset(x, y),
        moduleSize * (.18 + (index % 3) * .12),
        fill,
      );
    }
  }

  void _drawBossMotif(Canvas canvas, _StoryPalette palette) {
    final center = Offset(_snap(size.x * .5), _snap(size.y * .42));
    final radius = math.min(size.x, size.y) * .29;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * .13,
      math.pi * .74,
      false,
      _stroke(palette.accent, .25, 4),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 1.13,
      math.pi * .74,
      false,
      _stroke(palette.accent, .25, 4),
    );
  }

  void _drawDashSecretMotif(Canvas canvas, _StoryPalette palette) {
    final paint = Paint()..color = palette.accent.withValues(alpha: .20);
    for (var index = 0; index < 7; index += 1) {
      final center = Offset(
        _snap(size.x * (.2 + index * .1)),
        _snap(size.y * (.68 - index * .055)),
      );
      canvas.drawPath(_rightChevron(center, moduleSize * .45), paint);
    }
  }

  void _drawVerticalSecretMotif(Canvas canvas, _StoryPalette palette) {
    final x = _snap(size.x * .5);
    for (
      var index = 1;
      index < math.max(2, size.y ~/ (moduleSize * 1.6));
      index += 1
    ) {
      final y = _snap(size.y - index * moduleSize * 1.6);
      canvas.drawCircle(
        Offset(x, y),
        index.isEven ? 5 : 3,
        Paint()..color = palette.accent.withValues(alpha: .23),
      );
    }
  }

  void _drawRangedSecretMotif(Canvas canvas, _StoryPalette palette) {
    for (var index = 0; index < 4; index += 1) {
      final center = Offset(
        _snap(size.x * (.28 + index * .15)),
        _snap(size.y * (.30 + (index % 2) * .27)),
      );
      canvas.drawCircle(
        center,
        moduleSize * .55,
        _stroke(palette.accent, .22, 2),
      );
      canvas.drawCircle(
        center,
        4,
        Paint()..color = palette.accent.withValues(alpha: .24),
      );
    }
  }

  void _drawAscentMotif(Canvas canvas, _StoryPalette palette) {
    final path = Path()..moveTo(size.x * .26, size.y);
    for (var index = 1; index <= 6; index += 1) {
      final y = size.y * (1 - index / 7);
      final x = size.x * (index.isEven ? .68 : .32);
      path.quadraticBezierTo(size.x * .5, y + moduleSize, x, y);
    }
    canvas.drawPath(path, _stroke(palette.accent, .18, 2));
  }

  void _drawFractureMotif(Canvas canvas, _StoryPalette palette) {
    final origin = Offset(_snap(size.x * .5), _snap(size.y * .44));
    final paint = _stroke(palette.accent, .24, 2);
    for (var ray = 0; ray < 9; ray += 1) {
      final angle = ray * math.pi * 2 / 9 + .13;
      final inner =
          origin + Offset(math.cos(angle), math.sin(angle)) * moduleSize;
      final elbow =
          origin +
          Offset(math.cos(angle + .12), math.sin(angle + .12)) *
              moduleSize *
              2.2;
      final outer =
          origin + Offset(math.cos(angle), math.sin(angle)) * moduleSize * 4;
      canvas.drawPath(
        Path()
          ..moveTo(inner.dx, inner.dy)
          ..lineTo(elbow.dx, elbow.dy)
          ..lineTo(outer.dx, outer.dy),
        paint,
      );
    }
  }

  void _drawPendulumMotif(Canvas canvas, _StoryPalette palette) {
    final pivot = Offset(_snap(size.x * .5), 0);
    final bob = Offset(_snap(size.x * .62), _snap(size.y * .58));
    canvas.drawLine(pivot, bob, _stroke(palette.accent, .18, 3));
    canvas.drawCircle(bob, moduleSize, _stroke(palette.accent, .23, 3));
    canvas.drawArc(
      Rect.fromCenter(center: pivot, width: size.x * .48, height: size.y * 1.2),
      math.pi * .24,
      math.pi * .52,
      false,
      _stroke(palette.structure, .16, 1),
    );
  }

  void _drawCompressionMotif(Canvas canvas, _StoryPalette palette) {
    final paint = Paint()..color = palette.accent.withValues(alpha: .18);
    final yPositions = <double>[.28, .48, .68];
    for (final fraction in yPositions) {
      final y = _snap(size.y * fraction);
      canvas.drawPath(
        _rightChevron(Offset(size.x * .25, y), moduleSize * .65),
        paint,
      );
      canvas.save();
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
      canvas.drawPath(
        _rightChevron(Offset(size.x * .25, y), moduleSize * .65),
        paint,
      );
      canvas.restore();
    }
  }

  void _drawMergeMotif(Canvas canvas, _StoryPalette palette) {
    final target = Offset(_snap(size.x * .5), _snap(size.y * .48));
    final paint = _stroke(palette.accent, .22, 3);
    final first = Path()
      ..moveTo(0, size.y * .2)
      ..cubicTo(
        size.x * .22,
        size.y * .2,
        size.x * .28,
        target.dy,
        target.dx,
        target.dy,
      );
    final second = Path()
      ..moveTo(size.x, size.y * .74)
      ..cubicTo(
        size.x * .78,
        size.y * .74,
        size.x * .72,
        target.dy,
        target.dx,
        target.dy,
      );
    canvas.drawPath(first, paint);
    canvas.drawPath(second, paint);
    canvas.drawCircle(
      target,
      moduleSize * .55,
      _stroke(palette.highlight, .24, 2),
    );
  }

  void _drawFinalCoreMotif(Canvas canvas, _StoryPalette palette) {
    final center = Offset(_snap(size.x * .5), _snap(size.y * .44));
    final iris = math.min(size.x, size.y) * .24;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: iris * 2.1, height: iris * 1.25),
      Paint()..color = const Color(0x99010204),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: iris * 2.1, height: iris * 1.25),
      _stroke(palette.accent, .32, 4),
    );
    canvas.drawCircle(
      center,
      moduleSize * .7,
      Paint()..color = palette.highlight.withValues(alpha: .18),
    );
  }

  void _renderForegroundLayer(Canvas canvas) {
    final palette = _palette;
    final edgeWidth = math.min(moduleSize * 4, size.x * .16);
    canvas.drawRect(
      size.toRect(),
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          Offset(size.x, 0),
          <Color>[
            palette.voidColor.withValues(alpha: .78),
            palette.voidColor.withValues(alpha: 0),
            palette.voidColor.withValues(alpha: 0),
            palette.voidColor.withValues(alpha: .78),
          ],
          <double>[0, edgeWidth / size.x, 1 - edgeWidth / size.x, 1],
        ),
    );

    // Slanted corner silhouettes frame the room without suggesting a surface
    // that the player can stand on.
    final shadow = Paint()..color = palette.voidColor.withValues(alpha: .48);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.y)
        ..lineTo(0, size.y * .62)
        ..lineTo(edgeWidth * .58, size.y * .76)
        ..lineTo(edgeWidth, size.y)
        ..close(),
      shadow,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.x, size.y)
        ..lineTo(size.x, size.y * .58)
        ..lineTo(size.x - edgeWidth * .52, size.y * .73)
        ..lineTo(size.x - edgeWidth, size.y)
        ..close(),
      shadow,
    );
  }

  Paint _stroke(Color color, double alpha, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color.withValues(alpha: alpha);

  Path _rightChevron(Offset center, double radius) => Path()
    ..moveTo(center.dx - radius, center.dy - radius)
    ..lineTo(center.dx + radius, center.dy)
    ..lineTo(center.dx - radius, center.dy + radius)
    ..lineTo(center.dx - radius * .35, center.dy)
    ..close();

  Path _downChevron(Offset center, double radius) => Path()
    ..moveTo(center.dx - radius, center.dy - radius)
    ..lineTo(center.dx, center.dy + radius)
    ..lineTo(center.dx + radius, center.dy - radius)
    ..lineTo(center.dx, center.dy - radius * .35)
    ..close();

  double _snap(double value, [double unit = moduleSize]) =>
      (value / unit).roundToDouble() * unit;
}

final class _StoryPalette {
  const _StoryPalette({
    required this.voidColor,
    required this.fog,
    required this.structure,
    required this.highlight,
    required this.accent,
  });

  final Color voidColor;
  final Color fog;
  final Color structure;
  final Color highlight;
  final Color accent;
}

_StoryPalette _paletteFor(StoryRegionVisualTheme theme) => switch (theme) {
  StoryRegionVisualTheme.boot => const _StoryPalette(
    voidColor: Color(0xFF070A0D),
    fog: Color(0xFF141A1B),
    structure: Color(0xFF283235),
    highlight: Color(0xFF536061),
    accent: Color(0xFF796E51),
  ),
  StoryRegionVisualTheme.damage => const _StoryPalette(
    voidColor: Color(0xFF0D0908),
    fog: Color(0xFF211310),
    structure: Color(0xFF3A2721),
    highlight: Color(0xFF725244),
    accent: Color(0xFF9A6545),
  ),
  StoryRegionVisualTheme.temporal => const _StoryPalette(
    voidColor: Color(0xFF080A12),
    fog: Color(0xFF151725),
    structure: Color(0xFF2C2C40),
    highlight: Color(0xFF646078),
    accent: Color(0xFF8B7D63),
  ),
  StoryRegionVisualTheme.collision => const _StoryPalette(
    voidColor: Color(0xFF070C0C),
    fog: Color(0xFF101C1B),
    structure: Color(0xFF263A38),
    highlight: Color(0xFF59726D),
    accent: Color(0xFF6F847D),
  ),
  StoryRegionVisualTheme.optimizer => const _StoryPalette(
    voidColor: Color(0xFF050506),
    fog: Color(0xFF151517),
    structure: Color(0xFF2B2B30),
    highlight: Color(0xFF777579),
    accent: Color(0xFF9A8C68),
  ),
};
