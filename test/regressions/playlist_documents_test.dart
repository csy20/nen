import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nen/data/services/playlist_documents.dart';
import 'package:nen/domain/entities/entities.dart';
import 'package:nen/presentation/providers/di_providers.dart';
import 'package:nen/presentation/screens/playlists_screen.dart';
import 'package:nen/presentation/theme/nen_theme.dart';

import '../support/repositories.dart';

const _channel = MethodChannel('dev.csy20.nen/documents');
const _song = Song(
  id: 11,
  title: 'Track',
  artist: 'Artist',
  album: 'Album',
  albumId: 1,
  duration: Duration(minutes: 3),
  filePath: '',
  uri: 'content://media/external/audio/media/11',
  fileExtension: 'mp3',
  trackNumber: 1002,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void nativeReply(Future<Object?> Function(MethodCall) callback) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, callback);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<void> mount(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: NenTheme.buildDark(),
          home: const Scaffold(body: PlaylistsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer containerFor(FakePlaylistRepository repository) =>
      ProviderContainer(
        overrides: [
          playlistRepositoryProvider.overrideWithValue(repository),
          playlistDocumentsProvider.overrideWithValue(PlaylistDocuments()),
        ],
      );

  test('save sends backup contents to the system document bridge', () async {
    MethodCall? request;
    nativeReply((call) async {
      request = call;
      return true;
    });
    expect(
      await PlaylistDocuments().save('[{"name":"Library","songs":[]}]'),
      true,
    );
    expect(request!.method, 'savePlaylistBackup');
    expect(request!.arguments, {'contents': '[{"name":"Library","songs":[]}]'});
  });

  test('save and open preserve graceful user cancellation', () async {
    nativeReply((_) async => null);
    final documents = PlaylistDocuments();
    expect(await documents.save('[]'), false);
    expect(await documents.open(), isNull);
  });

  test('document I/O errors reach callers', () async {
    nativeReply(
      (_) async => throw PlatformException(code: 'document_io_error'),
    );
    await expectLater(
      PlaylistDocuments().save('[]'),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      PlaylistDocuments().open(),
      throwsA(isA<PlatformException>()),
    );
  });

  testWidgets(
    'a selected backup can be re-imported into a fresh playlist store',
    (tester) async {
      String? exported;
      nativeReply((call) async {
        if (call.method == 'savePlaylistBackup') {
          exported = (call.arguments as Map)['contents'] as String;
          return true;
        }
        return exported;
      });
      final original = FakePlaylistRepository([
        Playlist(
          id: 'source',
          name: 'Favorites',
          songs: const [_song],
          createdAt: DateTime(2026),
        ),
      ]);
      final sourceContainer = containerFor(original);
      final freshStore = FakePlaylistRepository();
      final destinationContainer = containerFor(freshStore);
      try {
        await mount(tester, sourceContainer);
        await tester.tap(find.byTooltip('Export Playlists'));
        await tester.pumpAndSettle();
        expect(find.text('Playlists exported'), findsOneWidget);
        expect(
          (jsonDecode(exported!) as List).single['songs'].single['uri'],
          _song.uri,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await mount(tester, destinationContainer);
        await tester.tap(find.byTooltip('Import Playlists'));
        await tester.pumpAndSettle();
        expect(freshStore.entries.single.name, 'Favorites');
        expect(freshStore.entries.single.songs.single.uri, _song.uri);
        expect(freshStore.entries.single.songs.single.trackNumber, 1002);
        expect(find.text('Imported 1 playlists'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        sourceContainer.dispose();
        destinationContainer.dispose();
      }
    },
  );

  for (final exporting in [false, true]) {
    testWidgets(
      'cancelled ${exporting ? 'export' : 'import'} does not report success',
      (tester) async {
        nativeReply((_) async => null);
        final repository = FakePlaylistRepository([
          Playlist(
            id: 'source',
            name: 'Favorites',
            songs: const [_song],
            createdAt: DateTime(2026),
          ),
        ]);
        final container = containerFor(repository);
        try {
          await mount(tester, container);
          await tester.tap(
            find.byTooltip(exporting ? 'Export Playlists' : 'Import Playlists'),
          );
          await tester.pumpAndSettle();
          expect(find.byType(SnackBar), findsNothing);
          expect(repository.entries.single.songs, [_song]);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        }
      },
    );
  }

  for (final invalid in [
    'not json',
    '[{"name":"Valid","songs":[]},{"name":"Invalid","songs":[{}]}]',
  ]) {
    testWidgets(
      'invalid backup is rejected before any playlist is imported: $invalid',
      (tester) async {
        nativeReply((_) async => invalid);
        final repository = FakePlaylistRepository();
        final container = containerFor(repository);
        try {
          await mount(tester, container);
          await tester.tap(find.byTooltip('Import Playlists'));
          await tester.pumpAndSettle();
          expect(repository.entries, isEmpty);
          expect(
            find.text(
              'Could not import playlists. Choose a valid nen backup and try again.',
            ),
            findsOneWidget,
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        }
      },
    );
  }

  testWidgets('failed export provides feedback and enables retry', (
    tester,
  ) async {
    nativeReply(
      (_) async => throw PlatformException(code: 'document_io_error'),
    );
    final repository = FakePlaylistRepository([
      Playlist(
        id: 'source',
        name: 'Favorites',
        songs: const [_song],
        createdAt: DateTime(2026),
      ),
    ]);
    final container = containerFor(repository);
    try {
      await mount(tester, container);
      await tester.tap(find.byTooltip('Export Playlists'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not export playlists. Please try again.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('Export Playlists'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    }
  });
}
