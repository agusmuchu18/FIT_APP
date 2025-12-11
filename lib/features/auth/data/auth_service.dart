import 'dart:async';
import 'dart:math';

class AuthService {
  AuthService._internal();

  static final AuthService instance = AuthService._internal();

  final Map<String, _UserRecord> _users = {};
  UserAuthSession? _currentUser;

  UserAuthSession? get currentUser => _currentUser;

  Future<UserAuthSession> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final record = _users[email.toLowerCase()];
    if (record == null || record.password != password) {
      throw Exception('Credenciales inválidas.');
    }
    _currentUser = record.session;
    return record.session;
  }

  Future<UserAuthSession> signUp(String name, String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final normalizedEmail = email.toLowerCase();
    if (_users.containsKey(normalizedEmail)) {
      throw Exception('El correo ya está registrado.');
    }

    final session = UserAuthSession(
      userId: _generateUserId(),
      name: name.trim(),
      email: normalizedEmail,
    );

    _users[normalizedEmail] = _UserRecord(session: session, password: password);
    _currentUser = session;
    return session;
  }

  Future<void> signOut() async {
    _currentUser = null;
  }

  String _generateUserId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = random.nextInt(999999).toString().padLeft(6, '0');
    return 'user_${timestamp}_$randomSuffix';
  }
}

class UserAuthSession {
  const UserAuthSession({
    required this.userId,
    required this.name,
    required this.email,
  });

  final String userId;
  final String name;
  final String email;
}

class _UserRecord {
  const _UserRecord({required this.session, required this.password});

  final UserAuthSession session;
  final String password;
}
