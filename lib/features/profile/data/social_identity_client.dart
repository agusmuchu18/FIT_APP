import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/data/account_storage_scope.dart';
import 'social_attestation.dart';

class SocialFailure implements Exception {
  const SocialFailure(this.code, this.message);
  final String code, message;
  @override
  String toString() => message;
}

class SocialCancellation {
  final _signal = Completer<void>();
  bool get cancelled => _signal.isCompleted;
  Future<void> get signal => _signal.future;
  void cancel() {
    if (!cancelled) _signal.complete();
  }
}

class SocialCredentials {
  const SocialCredentials(this.uid, this.token);
  final String uid, token;
}

class SocialProfile {
  const SocialProfile({
    required this.uid,
    required this.handle,
    required this.name,
    this.bio = '',
    this.link = '',
    this.discipline = '',
    this.visibility = 'private',
    this.relation = 'none',
    this.followers,
    this.following,
    this.discoverable = false,
  });
  factory SocialProfile.fromJson(Map<String, dynamic> json) => SocialProfile(
    uid: json['uid'] as String,
    handle: json['handle'] as String,
    name: json['displayName'] as String,
    bio: json['bio'] as String? ?? '',
    link: json['link'] as String? ?? '',
    discipline: json['discipline'] as String? ?? '',
    visibility: json['visibility'] as String? ?? 'private',
    relation: json['relationship'] as String? ?? 'none',
    followers: json['followerCount'] as int?,
    following: json['followingCount'] as int?,
    discoverable: json['discoverable'] as bool? ?? false,
  );
  final String uid, handle, name, bio, link, discipline, visibility, relation;
  final int? followers, following;
  final bool discoverable;
}

class SocialPage {
  const SocialPage(this.items, this.nextCursor);
  factory SocialPage.fromJson(Map<String, dynamic> json) => SocialPage(
    (json['items'] as List)
        .map((p) => SocialProfile.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList(),
    json['nextCursor'] as String?,
  );
  final List<SocialProfile> items;
  final String? nextCursor;
}

/// Callable protocol over the existing HTTP package. No second identity store.
/// Attestation must be supplied by the app's verified App Check adapter in production.
class SocialIdentityClient {
  SocialIdentityClient({
    required this.endpoint,
    required this.credentials,
    required this.currentUid,
    this.appCheckToken,
    http.Client? transport,
    this.timeout = const Duration(seconds: 15),
  }) : _http = transport ?? http.Client();
  factory SocialIdentityClient.firebase({
    Future<String?> Function()? appCheckToken,
  }) {
    const enabled = bool.fromEnvironment('FIT_SOCIAL_ENABLED');
    final initialized = Firebase.apps.isNotEmpty;
    final auth = initialized ? FirebaseAuth.instance : null;
    return SocialIdentityClient(
      endpoint: enabled && initialized
          ? Uri.https(
              'us-central1-${auth!.app.options.projectId}.cloudfunctions.net',
              '/socialIdentity',
            )
          : null,
      currentUid: () => auth?.currentUser?.uid,
      credentials: () async {
        final user = auth?.currentUser;
        if (user == null || user.isAnonymous) return null;
        final token = await user.getIdToken();
        return token == null ? null : SocialCredentials(user.uid, token);
      },
      appCheckToken: appCheckToken ?? SocialAttestation.token,
    );
  }
  final Uri? endpoint;
  final Future<SocialCredentials?> Function() credentials;
  final String? Function() currentUid;
  final Future<String?> Function()? appCheckToken;
  final Duration timeout;
  final http.Client _http;
  final Set<SocialCancellation> _active = {};
  bool _closed = false;
  bool get configured => endpoint != null;
  void _check(String scope, String id, SocialCancellation cancel) {
    if (_closed || cancel.cancelled) {
      throw const SocialFailure('cancelled', 'Consulta cancelada.');
    }
    if (scope != AccountStorageScope.current ||
        currentUid() != id ||
        scope != AccountStorageScope.forUser(id)) {
      throw const SocialFailure(
        'account-changed',
        'La cuenta cambió. Volvé a abrir el apartado.',
      );
    }
  }

  Future<Map<String, dynamic>> call(
    Map<String, dynamic> data, {
    SocialCancellation? cancellation,
  }) async {
    if (endpoint == null) {
      throw const SocialFailure(
        'not-enabled',
        'El servicio social aún no está habilitado en esta instalación.',
      );
    }
    if (endpoint!.scheme != 'https' &&
        !(kDebugMode &&
            endpoint!.scheme == 'http' &&
            ['127.0.0.1', 'localhost'].contains(endpoint!.host))) {
      throw const SocialFailure(
        'configuration',
        'La conexión social requiere un destino seguro.',
      );
    }
    final scope = AccountStorageScope.current,
        cancel = cancellation ?? SocialCancellation();
    _active.add(cancel);
    Timer? timer;
    var timedOut = false;
    try {
      timer = Timer(timeout, () {
        timedOut = true;
        cancel.cancel();
      });
      Future<T> wait<T>(Future<T> operation) => Future.any([
        operation,
        cancel.signal.then<T>(
          (_) => throw const SocialFailure('cancelled', 'Consulta cancelada.'),
        ),
      ]);
      final identity = await wait(credentials());
      if (identity == null) {
        throw const SocialFailure(
          'unauthenticated',
          'Iniciá sesión con una cuenta para usar funciones sociales.',
        );
      }
      _check(scope, identity.uid, cancel);
      final attestation = await wait(
        appCheckToken?.call() ?? Future<String?>.value(),
      );
      _check(scope, identity.uid, cancel);
      final request =
          http.AbortableRequest('POST', endpoint!, abortTrigger: cancel.signal)
            ..headers.addAll({
              'content-type': 'application/json',
              'authorization': 'Bearer ${identity.token}',
              'X-Firebase-AppCheck': ?attestation,
            })
            ..body = jsonEncode({'data': data});
      final response = await wait(
        _http.send(request).then(http.Response.fromStream),
      );
      _check(scope, identity.uid, cancel);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['error'] case final Map error) {
        final code = (error['status'] as String? ?? 'unavailable')
            .toLowerCase()
            .replaceAll('_', '-');
        throw SocialFailure(
          code,
          code == 'unauthenticated'
              ? 'No se pudo verificar tu sesión. Volvé a iniciar sesión y reintentá.'
              : error['message'] as String? ??
                    'No se pudo completar la acción.',
        );
      }
      if (response.statusCode != 200) {
        throw const SocialFailure(
          'unavailable',
          'El servicio no está disponible. Reintentá.',
        );
      }
      return Map<String, dynamic>.from((body['result'] ?? body['data']) as Map);
    } on SocialFailure catch (error) {
      if (timedOut && error.code == 'cancelled') {
        throw const SocialFailure(
          'timeout',
          'La conexión tardó demasiado. Reintentá.',
        );
      }
      rethrow;
    } on http.RequestAbortedException {
      throw SocialFailure(
        timedOut ? 'timeout' : 'cancelled',
        timedOut
            ? 'La conexión tardó demasiado. Reintentá.'
            : 'Consulta cancelada.',
      );
    } on TimeoutException {
      cancel.cancel();
      throw const SocialFailure(
        'timeout',
        'La conexión tardó demasiado. Reintentá.',
      );
    } on http.ClientException {
      throw const SocialFailure(
        'offline',
        'No se pudo conectar. Revisá tu conexión y reintentá.',
      );
    } catch (_) {
      throw const SocialFailure(
        'unavailable',
        'No se pudo leer la respuesta del servicio. Reintentá.',
      );
    } finally {
      timer?.cancel();
      _active.remove(cancel);
    }
  }

  Future<SocialPage> search(
    String query, {
    String? cursor,
    SocialCancellation? cancellation,
  }) => _decode(
    call({
      'action': 'search',
      'query': query,
      'cursor': ?cursor,
    }, cancellation: cancellation),
    SocialPage.fromJson,
  );
  Future<SocialProfile> profile(String id) => _decode(
    call({'action': 'getProfile', 'target': id}),
    SocialProfile.fromJson,
  );
  Future<SocialProfile> saveProfile(Map<String, dynamic> profile) => _decode(
    call({'action': 'saveProfile', 'profile': profile}),
    SocialProfile.fromJson,
  );
  Future<SocialPage> connections(String id, String type, {String? cursor}) =>
      _decode(
        call({
          'action': 'connections',
          'target': id,
          'type': type,
          'cursor': ?cursor,
        }),
        SocialPage.fromJson,
      );
  Future<T> _decode<T>(
    Future<Map<String, dynamic>> operation,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final data = await operation;
    try {
      return parse(data);
    } catch (_) {
      throw const SocialFailure(
        'unavailable',
        'No se pudo leer la respuesta del servicio. Reintentá.',
      );
    }
  }

  void close() {
    _closed = true;
    for (final op in _active) {
      op.cancel();
    }
    _http.close();
  }
}
