import 'dart:convert';

import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/profile/data/social_identity_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

// Fixed loopback/demo destinations. This file cannot write production data.
void main() {
  const enabled = bool.fromEnvironment('FIT_SOCIAL_TEST_EMULATORS');
  test(
    'Flutter client performs the authenticated identity/follow/privacy flow against real emulators',
    () async {
      final clients = <SocialIdentityClient>[];
      addTearDown(() {
        for (final client in clients) {
          client.close();
        }
        AccountStorageScope.current = '';
      });
      Future<SocialIdentityClient> account(String label) async {
        final id = '${DateTime.now().microsecondsSinceEpoch}$label';
        final response = await http.post(
          Uri.parse(
            'http://127.0.0.1:9197/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key',
          ),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'email': '$id@example.test',
            'password': 'local-test-only-password',
            'returnSecureToken': true,
          }),
        );
        expect(response.statusCode, 200);
        final data = jsonDecode(response.body) as Map<String, dynamic>,
            uid = data['localId'] as String;
        final client = SocialIdentityClient(
          endpoint: Uri.parse(
            'http://127.0.0.1:5197/demo-fit-social/us-central1/socialIdentity',
          ),
          currentUid: () => uid,
          credentials: () async =>
              SocialCredentials(uid, data['idToken'] as String),
        );
        clients.add(client);
        return client;
      }

      void owner(SocialIdentityClient client) => AccountStorageScope.current =
          AccountStorageScope.forUser(client.currentUid());
      final a = await account('a'), b = await account('b');
      owner(a);
      await a.saveProfile({
        'handle': 'client_a_${DateTime.now().millisecondsSinceEpoch}',
        'displayName': 'Cliente A',
      });
      owner(b);
      final handle = 'client_b_${DateTime.now().millisecondsSinceEpoch}';
      final saved = await b.saveProfile({
        'handle': handle,
        'displayName': 'Cliente B',
        'discoverable': true,
        'bio': 'Biografía privada',
      });
      expect(saved.visibility, 'private');
      owner(a);
      final found = (await a.search(handle)).items.single;
      expect(found.uid, b.currentUid());
      expect(found.bio, isEmpty);
      expect(
        (await a.call({
          'action': 'follow',
          'target': found.uid,
        }))['relationship'],
        'pending',
      );
      owner(b);
      expect(
        (await b.connections(b.currentUid()!, 'requests')).items.single.uid,
        a.currentUid(),
      );
      await b.call({
        'action': 'respond',
        'target': a.currentUid(),
        'accept': true,
      });
      owner(a);
      expect((await a.profile(found.uid)).bio, 'Biografía privada');
      await a.call({'action': 'unfollow', 'target': found.uid});
      expect((await a.profile(found.uid)).relation, 'none');
      owner(b);
      await b.call({'action': 'block', 'target': a.currentUid()});
      owner(a);
      expect((await a.search(handle)).items, isEmpty);
      await expectLater(
        a.profile(found.uid),
        throwsA(
          isA<SocialFailure>().having((e) => e.code, 'code', 'not-found'),
        ),
      );
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
