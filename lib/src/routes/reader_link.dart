// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/foundation.dart';

import 'router_config.dart';

/// A reader link waiting for the app's router: set where the link arrives, taken by the app (which owns the router
/// on screen) as soon as it is built, so a link that starts the app is opened too.
final pendingReaderLink = ValueNotifier<String?>(null);

/// The in-app location for a reader link, or null when [uri] isn't one.
///
/// Lets launchers, scripts and assistants open a series or a chapter from
/// outside the app (on Linux: `tsumiru tsumiru://manga/12/chapter/3456`):
///
/// * `tsumiru://manga/<mangaId>` opens the series page.
/// * `tsumiru://manga/<mangaId>/chapter/<chapterId>` opens the reader at that
///   chapter (the server's chapter id), resuming at the last page read.
String? readerLinkLocation(Uri uri) {
  if (uri.scheme != 'tsumiru' || uri.host != 'manga') return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  final mangaId = int.tryParse(segments.first);
  if (mangaId == null || mangaId <= 0) return null;
  if (segments.length == 1) return MangaRoute(mangaId: mangaId).location;
  if (segments.length != 3 || segments[1] != 'chapter') return null;
  final chapterId = int.tryParse(segments[2]);
  if (chapterId == null || chapterId <= 0) return null;
  return ReaderRoute(mangaId: mangaId, chapterId: chapterId).location;
}
