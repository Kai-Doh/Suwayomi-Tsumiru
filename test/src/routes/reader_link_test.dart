// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter_test/flutter_test.dart';
import 'package:tsumiru/src/routes/reader_link.dart';
import 'package:tsumiru/src/routes/router_config.dart';

void main() {
  String? location(String link) => readerLinkLocation(Uri.parse(link));

  group('readerLinkLocation', () {
    test('a chapter link opens the reader at that chapter', () {
      expect(
        location('tsumiru://manga/12/chapter/3456'),
        const ReaderRoute(mangaId: 12, chapterId: 3456).location,
      );
      expect(location('tsumiru://manga/12/chapter/3456'), '/manga/12/chapter/3456');
    });

    test('a series link opens the series page', () {
      expect(location('tsumiru://manga/12'), const MangaRoute(mangaId: 12).location);
      expect(location('tsumiru://manga/12/'), const MangaRoute(mangaId: 12).location);
    });

    test('anything else is not a reader link', () {
      for (final link in [
        'tsumiru://tracker-oauth?code=xyz',
        'https://manga/12/chapter/3',
        'tsumiru://manga',
        'tsumiru://manga/abc/chapter/3',
        'tsumiru://manga/0/chapter/3',
        'tsumiru://manga/12/chapter',
        'tsumiru://manga/12/chapter/-1',
        'tsumiru://manga/12/page/3',
        'tsumiru://manga/12/chapter/3/extra',
      ]) {
        expect(location(link), isNull, reason: link);
      }
    });
  });
}
