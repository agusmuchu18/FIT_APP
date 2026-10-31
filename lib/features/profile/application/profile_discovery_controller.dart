import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/social_identity_client.dart';

/// Owns one visible search. A new query cancels the old transport and page cursor.
class ProfileDiscoveryController extends ChangeNotifier {
  ProfileDiscoveryController(
    this.client, {
    this.debounce = const Duration(milliseconds: 300),
  });
  final SocialIdentityClient client;
  final Duration debounce;
  Timer? _timer;
  SocialCancellation? _request;
  int _generation = 0;
  bool _disposed = false;
  String query = '';
  List<SocialProfile> items = [];
  String? nextCursor;
  SocialFailure? failure;
  bool loading = false, loadingMore = false;
  final Set<String> pending = {};

  void search(String value, {bool immediate = false}) {
    query = value.trim();
    _timer?.cancel();
    _request?.cancel();
    _generation++;
    items = [];
    nextCursor = null;
    failure = null;
    loading = true;
    loadingMore = false;
    notifyListeners();
    if (immediate) {
      unawaited(_load(false));
    } else {
      _timer = Timer(debounce, () => unawaited(_load(false)));
    }
  }

  Future<void> more() async {
    if (loading || loadingMore || nextCursor == null) return;
    loadingMore = true;
    failure = null;
    notifyListeners();
    await _load(true);
  }

  Future<void> _load(bool append) async {
    final generation = _generation, request = _request = SocialCancellation();
    try {
      final result = await client.search(
        query,
        cursor: append ? nextCursor : null,
        cancellation: request,
      );
      if (_disposed || generation != _generation) return;
      final unique = {
        if (append)
          for (final item in items) item.uid: item,
      };
      for (final item in result.items) {
        unique.putIfAbsent(item.uid, () => item);
      }
      items = unique.values.toList();
      nextCursor = result.nextCursor;
    } on SocialFailure catch (error) {
      if (_disposed || generation != _generation || error.code == 'cancelled') {
        return;
      }
      failure = error;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggleFollow(SocialProfile profile) async {
    if (!pending.add(profile.uid)) return;
    failure = null;
    notifyListeners();
    try {
      await client.call({
        'action': profile.relation == 'none' ? 'follow' : 'unfollow',
        'target': profile.uid,
      });
      final updated = await client.profile(profile.uid);
      if (_disposed) return;
      items = [
        for (final item in items)
          if (item.uid == updated.uid) updated else item,
      ];
    } on SocialFailure catch (error) {
      if (!_disposed) failure = error;
    } finally {
      if (!_disposed) {
        pending.remove(profile.uid);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    _request?.cancel();
    super.dispose();
  }
}
