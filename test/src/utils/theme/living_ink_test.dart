// Kai's fork: Living Ink (lib/src/utils/theme/living_ink.dart).
//
// LIVING_INK_SHOTS=<dir> also renders a page in the day and night colours, with the grain, to <dir>/living-ink-*.png
// (run with HOME pointing at a scratch folder: the live test writes ~/.local/state/living-ink/tsumiru.json there).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsumiru/src/constants/app_theme.dart';
import 'package:tsumiru/src/utils/theme/app_theme_builder.dart';
import 'package:tsumiru/src/utils/theme/living_ink.dart';

Map<String, dynamic> sample({required bool light, String? grain}) => {
  'light': light,
  'bg': light ? '#efe9e2' : '#151515',
  'bg2': light ? '#e6e0d9' : '#1d1c1c',
  'ink': light ? '#17181c' : '#ebe2d8',
  'muted': light ? '#6b6e76' : '#888498',
  'faint': light ? '#8f9198' : '#64616e',
  'accent': light ? '#2e65a0' : '#b8afdf',
  'accent2': light ? '#117373' : '#9fe7e0',
  'danger': light ? '#b33243' : '#ff7a8f',
  'border': light ? '#17181c1f' : '#ebe2d817',
  'on_accent': light ? '#efe9e2' : '#151515',
  'accent_bg': light ? '#d6dae0' : '#35333b',
  'accent_fill': light ? '#c4ccd8' : '#464451',
  'grad': light ? ['#2e65a0', '#117373'] : ['#b8afdf', '#9fe7e0'],
  'grain': ?grain,
  'grain_blend': light ? 'multiply' : 'screen',
};

void main() {
  test('reads the colours of the moment (#rrggbbaa = alpha last)', () {
    final ink = LivingInk.fromJson(sample(light: false))!;
    expect(ink.light, isFalse);
    expect(ink.brightness, Brightness.dark);
    expect(ink.tokens.bg, const Color(0xFF151515));
    expect(ink.tokens.border, const Color(0x17EBE2D8));
    expect(ink.grainMultiply, isFalse);
    expect(LivingInk.fromJson({}), isNull);
  });

  test('the theme takes the tokens in place of the named theme', () {
    final ink = LivingInk.fromJson(sample(light: true))!;
    final theme = buildAppTheme(
      theme: AppTheme.indigoNight,
      brightness: Brightness.light,
      customSeed: const Color(0xFF7C7BFF),
      amoled: false,
      tokensOverride: ink.tokens,
    );
    expect(theme.colorScheme.surface, const Color(0xFFEFE9E2));
    expect(theme.colorScheme.onSurface, const Color(0xFF17181C));
    expect(theme.colorScheme.primary, const Color(0xFF2E65A0));
  });

  test('follows the file live: new colours, then off', () async {
    final home = Platform.environment['HOME']!;
    final file = File('$home/.local/state/living-ink/tsumiru.json');
    if (!home.contains('scratch') &&
        !home.startsWith(Directory.systemTemp.path)) {
      markTestSkipped('needs HOME pointing at a scratch folder');
      return;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(sample(light: false)));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final seen = <bool?>[];
    container.listen(livingInkProvider, (_, next) {
      if (next.hasValue) seen.add(next.value?.light);
    }, fireImmediately: true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await Future<void>.delayed(
      const Duration(seconds: 1),
    ); // (mtime resolution)
    file.writeAsStringSync(jsonEncode(sample(light: true)));
    await Future<void>.delayed(const Duration(seconds: 4));
    file.writeAsStringSync('');
    await Future<void>.delayed(const Duration(seconds: 4));
    expect(seen, [false, true, null]);
  });

  final shots = Platform.environment['LIVING_INK_SHOTS'];
  for (final light in [false, true]) {
    testWidgets(
      'renders a page in the ${light ? 'day' : 'night'} colours with the grain',
      (tester) async {
        if (shots == null) return;
        final home =
            Platform.environment['REAL_HOME'] ?? Platform.environment['HOME']!;
        final grain =
            '$home/.local/share/living-ink/grain-${light ? 'day' : 'night'}.png';
        final ink = LivingInk.fromJson(sample(light: light, grain: grain))!;
        tester.view.physicalSize = const Size(900, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final theme = buildAppTheme(
          theme: AppTheme.indigoNight,
          brightness: ink.brightness,
          customSeed: const Color(0xFF7C7BFF),
          amoled: false,
          tokensOverride: ink.tokens,
        );
        final app = MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: LivingInkGrain(
            ink: ink,
            child: Scaffold(
              appBar: AppBar(title: const Text('Library')),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.book),
                      title: const Text('Chapter 112'),
                      subtitle: const Text('Read yesterday'),
                      trailing: FilledButton(
                        onPressed: () {},
                        child: const Text('Read'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      const Chip(label: Text('Unread')),
                      FilterChip(
                        selected: true,
                        onSelected: (_) {},
                        label: const Text('Downloaded'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Filter'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(height: 180, color: Colors.white), // a manga page
                ],
              ),
            ),
          ),
        );
        // (the grain image loads on real time, off the test clock)
        await tester.runAsync(() async {
          await tester.pumpWidget(app);
          await Future<void>.delayed(const Duration(seconds: 1));
        });
        await tester.pump();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('$shots/living-ink-${light ? 'day' : 'night'}.png'),
        );
      },
    );
  }
}
