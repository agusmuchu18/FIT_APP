import 'dart:async';

import 'package:flutter/material.dart';

import 'account_storage_scope.dart';

/// Removes the previous Navigator while restoring the next account's storage.
/// The generation check rejects a late restoration for a previous account.
class AccountSessionGate<T> extends StatefulWidget {
  const AccountSessionGate({
    super.key,
    required this.accounts,
    required this.restore,
    required this.builder,
    this.theme,
  });
  final Stream<String?> accounts;
  final Future<T> Function(String? userId, String scope) restore;
  final Widget Function(T value) builder;
  final ThemeData? theme;
  @override
  State<AccountSessionGate<T>> createState() => _AccountSessionGateState<T>();
}

class _AccountSessionGateState<T> extends State<AccountSessionGate<T>> {
  StreamSubscription<String?>? _subscription;
  T? _value;
  Object? _error;
  String? _userId;
  bool _receivedAccount = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _subscription = widget.accounts.distinct().listen(_restore);
  }

  Future<void> _restore(String? userId) async {
    final generation = ++_generation;
    final scope = AccountStorageScope.forUser(userId);
    AccountStorageScope.current = scope;
    setState(() {
      _userId = userId;
      _receivedAccount = true;
      _value = null;
      _error = null;
    });
    try {
      // MaterialApp uses a shared Navigator key for the workout mini bar.
      // Dispose its old route stack before even an instant restore can remount it.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generation != _generation) return;
      final value = await widget.restore(userId, scope);
      if (!mounted || generation != _generation) return;
      setState(() => _value = value);
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    if (value != null) {
      return KeyedSubtree(
        key: ValueKey(_generation),
        child: widget.builder(value),
      );
    }
    return MaterialApp(
      theme: widget.theme,
      home: Scaffold(
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No se pudieron abrir tus datos. Se conservan para reintentar.',
                    ),
                    if (_receivedAccount)
                      FilledButton(
                        onPressed: () => _restore(_userId),
                        child: const Text('Reintentar'),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
