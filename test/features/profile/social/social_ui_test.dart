import 'dart:convert';

import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/groups/presentation/pages/discover_profiles_panel.dart';
import 'package:fit_app/features/groups/presentation/pages/groups_list_screen.dart';
import 'package:fit_app/features/profile/data/social_identity_client.dart';
import 'package:fit_app/features/profile/profile_controller.dart';
import 'package:fit_app/features/profile/public_profile_screen.dart';
import 'package:fit_app/features/profile/social_profile_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AccountStorageScope.current = AccountStorageScope.forUser('a');
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => AccountStorageScope.current = '');
  const person = {
    'uid': 'b',
    'handle': 'atleta_test',
    'displayName': 'Atleta de prueba',
    'visibility': 'public',
    'relationship': 'none',
    'bio': 'Entrenamiento de fuerza',
    'followerCount': 0,
    'followingCount': 0,
  };
  SocialIdentityClient api(
    Future<http.Response> Function(Map<String, dynamic>) handler,
  ) {
    final client = SocialIdentityClient(
      endpoint: Uri.https('identity.example.test', '/socialIdentity'),
      currentUid: () => 'a',
      credentials: () async => const SocialCredentials('a', 'test-token'),
      transport: MockClient(
        (r) => handler(
          (jsonDecode(r.body) as Map)['data'] as Map<String, dynamic>,
        ),
      ),
    );
    addTearDown(client.close);
    return client;
  }

  http.Response ok(Object data) =>
      http.Response(jsonEncode({'result': data}), 200);

  testWidgets(
    'Discover stays inside Groups and follow state comes from the server',
    (t) async {
      var following = false;
      final calls = <String>[];
      final client = api((data) async {
        calls.add(data['action'] as String);
        final profile = {
          ...person,
          'relationship': following ? 'accepted' : 'none',
        };
        return switch (data['action']) {
          'search' => ok({
            'items': [profile],
            'nextCursor': null,
          }),
          'getProfile' => ok(profile),
          'follow' => () {
            following = true;
            return ok({'relationship': 'accepted'});
          }(),
          _ => throw StateError('unexpected action'),
        };
      });
      await t.pumpWidget(
        MaterialApp(home: GroupsListScreen(socialClient: client)),
      );
      await t.pumpAndSettle();
      expect(find.text('Crear grupo'), findsOneWidget);
      expect(calls, isEmpty);
      await t.tap(find.text('Descubrir'));
      await t.pumpAndSettle();
      expect(find.text('Atleta de prueba'), findsOneWidget);
      await t.tap(find.text('Seguir'));
      await t.pumpAndSettle();
      expect(find.text('Siguiendo'), findsOneWidget);
      expect(following, isTrue);
      await t.tap(find.text('Mis grupos'));
      await t.pumpAndSettle();
      expect(find.text('Crear grupo'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('offline shows a retry and does not masquerade as no results', (
    t,
  ) async {
    var offline = true;
    final client = api((_) async {
      if (offline) throw http.ClientException('test offline');
      return ok({'items': [], 'nextCursor': null});
    });
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DiscoverProfilesPanel(client: client)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('Revisá tu conexión'), findsOneWidget);
    expect(
      find.text('Todavía no hay perfiles públicos para sugerir.'),
      findsNothing,
    );
    offline = false;
    await t.tap(find.text('Reintentar'));
    await t.pumpAndSettle();
    expect(
      find.text('Todavía no hay perfiles públicos para sugerir.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'public opt-in needs consent; cancellation does not send a save',
    (t) async {
      var saves = 0;
      final client = api((data) async {
        if (data['action'] == 'getProfile') {
          return http.Response('{"error":{"status":"NOT_FOUND"}}', 404);
        }
        saves++;
        return ok({
          'uid': 'a',
          'relationship': 'self',
          ...data['profile'] as Map,
        });
      });
      final private = ProfileController();
      await private.ready;
      await t.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SocialProfileEditor(
                      client: client,
                      profileController: private,
                    ),
                  ),
                ),
                child: const Text('Editar identidad'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Editar identidad'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextFormField, 'Nombre visible'),
        'Mi nombre',
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Nombre de usuario'),
        'mi_usuario',
      );
      await t.tap(find.text('Perfil público'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Guardar identidad'));
      await t.tap(find.text('Guardar identidad'));
      await t.pumpAndSettle();
      expect(find.text('Compartir tu identidad deportiva'), findsOneWidget);
      expect(saves, 0);
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      expect(saves, 0);
      await t.tap(find.text('Guardar identidad'));
      await t.pumpAndSettle();
      await t.tap(find.text('Guardar visibilidad'));
      await t.pumpAndSettle();
      expect(saves, 1);
      expect(private.displayName.value, 'Mi nombre');
      expect(find.text('Editar identidad'), findsOneWidget);
    },
  );

  testWidgets(
    'private profiles expose neither health tabs nor invented counters; requests are actionable',
    (t) async {
      final client = api(
        (data) async => ok(
          data['action'] == 'getProfile'
              ? {
                  ...person,
                  'visibility': 'private',
                  'followerCount': null,
                  'followingCount': null,
                  'bio': '',
                }
              : {
                  'items': [
                    {...person, 'relationship': 'pending'},
                  ],
                  'nextCursor': null,
                },
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          home: PublicProfileScreen(client: client, uid: 'b'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Solicitar seguimiento'), findsOneWidget);
      for (final label in ['Fotos', 'Estadísticas', 'PRs', '0 seguidores']) {
        expect(find.text(label), findsNothing);
      }
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialConnections(client: client, uid: 'a', type: 'requests'),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Aceptar'), findsOneWidget);
      expect(find.text('Rechazar'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
