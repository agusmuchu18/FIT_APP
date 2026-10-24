import 'dart:convert';
import 'dart:ui' as ui;

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/groups/presentation/pages/groups_list_screen.dart';
import 'package:fit_app/features/profile/data/social_identity_client.dart';
import 'package:fit_app/features/profile/public_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AccountStorageScope.current = AccountStorageScope.forUser('golden');
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => AccountStorageScope.current = '');
  SocialIdentityClient client({bool private = false}) => SocialIdentityClient(
    endpoint: Uri.https('identity.example.test', '/socialIdentity'),
    currentUid: () => 'golden',
    credentials: () async => const SocialCredentials('golden', 'test-token'),
    transport: MockClient((r) async {
      final action = ((jsonDecode(r.body) as Map)['data'] as Map)['action'];
      final profile = {
        'uid': 'fixture-only',
        'handle': 'marina_fuerza',
        'displayName': 'Marina · Fuerza y movilidad',
        'visibility': private ? 'private' : 'public',
        'relationship': 'none',
        'bio': private ? '' : 'Entreno para sentirme más fuerte cada día.',
        'discipline': private ? '' : 'Fuerza · Movilidad',
        'followerCount': private ? null : 128,
        'followingCount': private ? null : 54,
      };
      return http.Response(
        jsonEncode({
          'result': action == 'search'
              ? {
                  'items': [profile],
                  'nextCursor': null,
                }
              : profile,
        }),
        200,
      );
    }),
  );
  Future<void> surface(
    WidgetTester t,
    Size size,
    Widget screen, {
    bool light = false,
    double scale = 1,
  }) async {
    for (final font in {
      'Inter': 'assets/fonts/Inter-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final bytes = await rootBundle.load(font.value);
      await ui.loadFontFromList(
        bytes.buffer.asUint8List(),
        fontFamily: font.key,
      );
    }
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: light ? AppTheme.light : AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: RepaintBoundary(child: screen),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'discover has no new main destination and is usable at small width with large text',
    (t) async {
      final api = client();
      addTearDown(api.close);
      await surface(
        t,
        const Size(390, 844),
        GroupsListScreen(socialClient: api),
      );
      await t.tap(find.text('Descubrir'));
      await t.pumpAndSettle();
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('social_discovery.png'),
      );
      await surface(
        t,
        const Size(320, 844),
        GroupsListScreen(socialClient: api),
        scale: 2,
      );
      await t.pumpAndSettle();
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('social_discovery_accessible.png'),
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'private profile uses authorized fields only and supports light high text',
    (t) async {
      final api = client(private: true);
      addTearDown(api.close);
      await surface(
        t,
        const Size(320, 844),
        PublicProfileScreen(client: api, uid: 'fixture-only'),
        light: true,
        scale: 2,
      );
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('social_public_profile_private.png'),
      );
      expect(t.takeException(), isNull);
    },
  );
}
