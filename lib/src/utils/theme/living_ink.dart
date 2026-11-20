// Kai's fork: Living Ink, the Omarchy theme whose colours follow the day (ink at night, paper by day).
//
// On Linux, while Living Ink is the desktop theme, `living-ink-apps` keeps
// ~/.local/state/living-ink/tsumiru.json up to date with the colours of the moment (already held to their contrast
// floors) and the paper grain to lay over the app. Tsumiru follows that file live: no restart, no setting. An empty
// file, or none, means Living Ink isn't on: the app's own theme applies as usual.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'theme_tokens.dart';

class LivingInk {
  const LivingInk({
    required this.light,
    required this.tokens,
    this.grain,
    this.grainMultiply = true,
  });

  final bool light;
  final ThemeTokens tokens;
  final String? grain; // a tiling PNG, one texel per screen pixel
  final bool
  grainMultiply; // by day multiplied in (paper fibre); at night screened in (a faint lift)

  Brightness get brightness => light ? Brightness.light : Brightness.dark;

  static Color _c(Object? v) {
    final s = (v as String).replaceFirst('#', '');
    final argb = s.length == 6
        ? 'ff$s'
        : s.substring(6) + s.substring(0, 6); // #rrggbb or #rrggbbaa
    return Color(int.parse(argb, radix: 16));
  }

  static LivingInk? fromJson(Map<String, dynamic> j) {
    if (j['bg'] == null) return null;
    final grad = j['grad'] as List?;
    return LivingInk(
      light: j['light'] == true,
      grain: j['grain'] as String?,
      grainMultiply: j['grain_blend'] != 'screen',
      tokens: ThemeTokens(
        bg: _c(j['bg']),
        bg2: _c(j['bg2']),
        ink: _c(j['ink']),
        muted: _c(j['muted']),
        faint: _c(j['faint']),
        accent: _c(j['accent']),
        accent2: _c(j['accent2']),
        danger: _c(j['danger']),
        border: _c(j['border']),
        onAccent: _c(j['on_accent']),
        accentBg: _c(j['accent_bg']),
        accentFill: _c(j['accent_fill']),
        grad: grad == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [for (final c in grad) _c(c)],
              ),
      ),
    );
  }
}

/// The colours of the moment, or null when Living Ink isn't the desktop theme (or not on Linux).
final livingInkProvider = StreamProvider<LivingInk?>((ref) async* {
  if (kIsWeb || !Platform.isLinux) {
    yield null;
    return;
  }
  final home = Platform.environment['HOME'] ?? '';
  final file = File('$home/.local/state/living-ink/tsumiru.json');
  DateTime? seen;
  LivingInk? read() {
    try {
      final text = file.readAsStringSync();
      if (text.trim().isEmpty) return null;
      return LivingInk.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // (a stat every 3 s: the file changes a few times an hour, when the engine applies new colours)
  while (true) {
    final stamp = file.existsSync() ? file.lastModifiedSync() : DateTime(0);
    if (stamp != seen) {
      seen = stamp;
      yield read();
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
});

/// The paper grain over the whole app, like behind the terminals: drawn last, ignores the pointer.
class LivingInkGrain extends StatefulWidget {
  const LivingInkGrain({super.key, required this.ink, required this.child});

  final LivingInk? ink;
  final Widget child;

  @override
  State<LivingInkGrain> createState() => _LivingInkGrainState();
}

class _LivingInkGrainState extends State<LivingInkGrain> {
  ui.Image? _image;
  String? _path;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LivingInkGrain old) {
    super.didUpdateWidget(old);
    _load();
  }

  Future<void> _load() async {
    final path = widget.ink?.grain;
    if (path == _path) return;
    _path = path;
    if (path == null) {
      setState(() => _image = null);
      return;
    }
    try {
      final codec = await ui.instantiateImageCodec(
        await File(path).readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      if (mounted && _path == path) setState(() => _image = frame.image);
    } catch (_) {
      if (mounted) setState(() => _image = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final ink = widget.ink;
    if (ink == null || image == null) return widget.child;
    return CustomPaint(
      foregroundPainter: _GrainPainter(
        image,
        ink.grainMultiply,
        MediaQuery.devicePixelRatioOf(context),
      ),
      child: widget.child,
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.image, this.multiply, this.dpr);

  final ui.Image image;
  final bool multiply;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = 1 / dpr;
    final matrix = Float64List.fromList([
      scale,
      0,
      0,
      0,
      0,
      scale,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
    ]);
    final paint = Paint()
      ..shader = ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        matrix,
      )
      ..blendMode = multiply ? BlendMode.multiply : BlendMode.screen;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.image != image || old.multiply != multiply || old.dpr != dpr;
}
