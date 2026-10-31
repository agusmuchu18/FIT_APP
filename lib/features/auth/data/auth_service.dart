import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  bool get isBackendAvailable => Firebase.apps.isNotEmpty;

  UserAuthSession? get currentUser {
    if (!isBackendAvailable) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return UserAuthSession.fromFirebaseUser(user);
  }

  Future<UserAuthSession> signIn(String email, String password) async {
    _requireBackend();
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('No se pudo iniciar la sesión.');
      }
      return UserAuthSession.fromFirebaseUser(user);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_messageFor(error));
    }
  }

  Future<UserAuthSession> signUp(
    String name,
    String email,
    String password,
  ) async {
    _requireBackend();
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('No se pudo crear la cuenta.');
      }

      final displayName = name.trim();
      if (displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
      }
      return UserAuthSession(
        userId: user.uid,
        name: displayName,
        email: user.email ?? email.trim().toLowerCase(),
        isAnonymous: false,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_messageFor(error));
    }
  }

  Future<UserAuthSession?> signInAnonymously() async {
    if (!isBackendAvailable) return null;
    final current = FirebaseAuth.instance.currentUser;
    if (current?.isAnonymous ?? false) {
      return UserAuthSession.fromFirebaseUser(current!);
    }
    try {
      final credential = await FirebaseAuth.instance.signInAnonymously();
      final user = credential.user;
      return user == null ? null : UserAuthSession.fromFirebaseUser(user);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_messageFor(error));
    }
  }

  Future<void> signOut() async {
    if (isBackendAvailable) {
      await FirebaseAuth.instance.signOut();
    }
  }

  void _requireBackend() {
    if (!isBackendAvailable) {
      throw const AuthException(
        'El acceso con cuenta no está disponible. Podés continuar sin cuenta.',
      );
    }
  }

  String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'El email no tiene un formato válido.';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Email o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'El correo ya está registrado.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Probá nuevamente más tarde.';
      case 'network-request-failed':
        return 'No se pudo conectar. Revisá tu conexión a internet.';
      case 'operation-not-allowed':
        return 'Este método de acceso todavía no está habilitado.';
      default:
        return 'No pudimos completar la autenticación.';
    }
  }
}

class UserAuthSession {
  const UserAuthSession({
    required this.userId,
    required this.name,
    required this.email,
    required this.isAnonymous,
  });

  factory UserAuthSession.fromFirebaseUser(User user) {
    return UserAuthSession(
      userId: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      isAnonymous: user.isAnonymous,
    );
  }

  final String userId;
  final String name;
  final String email;
  final bool isAnonymous;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
