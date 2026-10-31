import 'dart:async';
import 'dart:convert';

import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/profile/application/profile_discovery_controller.dart';
import 'package:fit_app/features/profile/data/social_identity_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> profile(String id, {String relation = 'none'}) => {
  'uid': id,
  'handle': id,
  'displayName': 'Persona $id',
  'relationship': relation,
};
http.Response result(Object data) =>
    http.Response(jsonEncode({'result': data}), 200);

void main() {
  setUp(() => AccountStorageScope.current = AccountStorageScope.forUser('a'));
  tearDown(() => AccountStorageScope.current = '');
  SocialIdentityClient client(
    http.Client transport, {
    Future<SocialCredentials?> Function()? credentials,
    Duration? timeout,
  }) => SocialIdentityClient(
    endpoint: Uri.https('identity.example.test', '/socialIdentity'),
    currentUid: () =>
        AccountStorageScope.current == AccountStorageScope.forUser('a')
        ? 'a'
        : 'b',
    credentials:
        credentials ?? () async => const SocialCredentials('a', 'test-token'),
    transport: transport,
    timeout: timeout ?? const Duration(seconds: 2),
  );

  test('disabled service never requests credentials or sends data', () async {
    final api = SocialIdentityClient(
      endpoint: null,
      credentials: () async => throw StateError('must not run'),
      currentUid: () => 'a',
    );
    addTearDown(api.close);
    await expectLater(
      api.search(''),
      throwsA(
        isA<SocialFailure>().having((e) => e.code, 'code', 'not-enabled'),
      ),
    );
  });
  test('uses current Firebase identity and the callable protocol with only selected fields', () async {
    final api = client(
      MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(jsonDecode(request.body), {
          'data': {'action': 'getProfile', 'target': 'b'},
        });
        return result(profile('b'));
      }),
    );
    addTearDown(api.close);
    expect((await api.profile('b')).uid, 'b');
  });
  test('a response for the previous account is discarded', () async {
    final response = Completer<http.Response>(), sent = Completer<void>();
    final api = client(
      MockClient((_) {
        sent.complete();
        return response.future;
      }),
    );
    addTearDown(api.close);
    final pending = api.profile('b');
    await sent.future;
    AccountStorageScope.current = AccountStorageScope.forUser('b');
    response.complete(result(profile('b')));
    await expectLater(
      pending,
      throwsA(
        isA<SocialFailure>().having((e) => e.code, 'code', 'account-changed'),
      ),
    );
  });
  test(
    'cancellation while acquiring a token prevents a later HTTP request',
    () async {
      final token = Completer<SocialCredentials?>(),
          cancel = SocialCancellation();
      var sent = false;
      final api = client(
        MockClient((_) async {
          sent = true;
          return result({});
        }),
        credentials: () => token.future,
      );
      addTearDown(api.close);
      final pending = api.search('jose', cancellation: cancel);
      cancel.cancel();
      await expectLater(
        pending,
        throwsA(
          isA<SocialFailure>().having((e) => e.code, 'code', 'cancelled'),
        ),
      );
      token.complete(const SocialCredentials('a', 'test-token'));
      await Future<void>.delayed(Duration.zero);
      expect(sent, isFalse);
    },
  );
  test('server denial, invalid payload and timeout remain actionable failures', () async {
    for (final entry in [
      (
        http.Response(
          '{"error":{"status":"PERMISSION_DENIED","message":"Acceso privado"}}',
          403,
        ),
        'permission-denied',
      ),
      (http.Response('invalid', 200), 'unavailable'),
    ]) {
      final api = client(MockClient((_) async => entry.$1));
      await expectLater(
        api.profile('b'),
        throwsA(isA<SocialFailure>().having((e) => e.code, 'code', entry.$2)),
      );
      api.close();
    }
    final api = client(
      MockClient((_) => Completer<http.Response>().future),
      timeout: const Duration(milliseconds: 10),
    );
    addTearDown(api.close);
    await expectLater(
      api.profile('b'),
      throwsA(isA<SocialFailure>().having((e) => e.code, 'code', 'timeout')),
    );
  });
  test('debounce sends only the latest query; pagination deduplicates and query changes reset cursor', () async {
    final requests = <Map<String, dynamic>>[];
    final api = client(
      MockClient((request) async {
        final data =
            (jsonDecode(request.body) as Map)['data'] as Map<String, dynamic>;
        requests.add(data);
        return result({
          'items': data.containsKey('cursor')
              ? [profile('b'), profile('c')]
              : [profile('b')],
          'nextCursor': data.containsKey('cursor') ? null : 'page-two',
        });
      }),
    );
    final controller = ProfileDiscoveryController(
      api,
      debounce: const Duration(milliseconds: 10),
    );
    addTearDown(() {
      controller.dispose();
      api.close();
    });
    controller.search('jo');
    controller.search('jose');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(requests.length, 1);
    expect(requests.single['query'], 'jose');
    await controller.more();
    expect(controller.items.map((p) => p.uid), ['b', 'c']);
    controller.search('ana', immediate: true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(requests.last.containsKey('cursor'), isFalse);
  });
  test(
    'out of order search responses cannot replace the current query',
    () async {
      final older = Completer<http.Response>(), firstSent = Completer<void>();
      final api = client(
        MockClient((request) {
          final data = (jsonDecode(request.body) as Map)['data'] as Map;
          if (data['query'] == 'old') {
            firstSent.complete();
            return older.future;
          }
          return Future.value(
            result({
              'items': [profile('new')],
              'nextCursor': null,
            }),
          );
        }),
      );
      final controller = ProfileDiscoveryController(api);
      addTearDown(() {
        controller.dispose();
        api.close();
      });
      controller.search('old', immediate: true);
      await firstSent.future;
      controller.search('new', immediate: true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      older.complete(
        result({
          'items': [profile('old')],
          'nextCursor': 'obsolete',
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.items.single.uid, 'new');
      expect(controller.nextCursor, isNull);
    },
  );
  test('a failed follow keeps its previous state and successful retry clears the error', () async {
    var fail = true;
    final api = client(
      MockClient((request) async {
        final action =
            ((jsonDecode(request.body) as Map)['data'] as Map)['action'];
        if (action == 'search') {
          return result({
            'items': [profile('b')],
            'nextCursor': null,
          });
        }
        if (action == 'follow' && fail) {
          throw http.ClientException('test offline');
        }
        return result(
          action == 'getProfile'
              ? profile('b', relation: 'accepted')
              : {'relationship': 'accepted'},
        );
      }),
    );
    final controller = ProfileDiscoveryController(api);
    addTearDown(() {
      controller.dispose();
      api.close();
    });
    controller.search('', immediate: true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await controller.toggleFollow(controller.items.single);
    expect(controller.items.single.relation, 'none');
    expect(controller.failure?.code, 'offline');
    expect(controller.pending, isEmpty);
    fail = false;
    await controller.toggleFollow(controller.items.single);
    expect(controller.items.single.relation, 'accepted');
    expect(controller.failure, isNull);
  });
}
