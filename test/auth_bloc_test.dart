import 'package:flutter_test/flutter_test.dart';
import 'package:agrinova/features/auth/bloc/auth_bloc.dart' as agrinova_auth;
import 'package:agrinova/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository implements AuthRepository {
  bool shouldFail = false;
  String failMessage = 'Invalid login credentials';
  bool requireEmailConfirmation = false;

  @override
  User? get currentUser => null;

  @override
  Future<AuthResponse> signIn({required String email, required String password}) async {
    if (shouldFail) throw Exception(failMessage);
    return AuthResponse(
      session: Session(
        accessToken: 'mock_access_token',
        tokenType: 'bearer',
        user: const User(
          id: 'user-123',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01',
        ),
      ),
    );
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (shouldFail) throw Exception(failMessage);
    if (requireEmailConfirmation) {
      return AuthResponse(session: null);
    }
    return AuthResponse(
      session: Session(
        accessToken: 'mock_access_token',
        tokenType: 'bearer',
        user: const User(
          id: 'user-123',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01',
        ),
      ),
    );
  }

  @override
  Future<void> resetPassword({required String email}) async {
    if (shouldFail) throw Exception(failMessage);
  }

  @override
  Future<void> signOut() async {
    if (shouldFail) throw Exception(failMessage);
  }
}

void main() {
  group('AuthBloc Unit Tests', () {
    late MockAuthRepository mockRepo;

    setUp(() {
      mockRepo = MockAuthRepository();
    });

    test('Initial state is AuthInitial', () {
      final bloc = agrinova_auth.AuthBloc(authRepository: mockRepo);
      expect(bloc.state, isA<agrinova_auth.AuthInitial>());
      bloc.close();
    });

    test('SignIn failure emits AuthLoading then AuthFailure', () async {
      mockRepo.shouldFail = true;
      mockRepo.failMessage = 'Invalid login credentials';
      final bloc = agrinova_auth.AuthBloc(authRepository: mockRepo);

      final expectedStates = [
        isA<agrinova_auth.AuthLoading>(),
        predicate<agrinova_auth.AuthState>((state) =>
            state is agrinova_auth.AuthFailure &&
            state.message == 'Email atau password salah.'),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(const agrinova_auth.AuthSignInRequested(
        email: 'test@example.com',
        password: 'wrongpassword',
      ));
    });

    test('SignUp with email confirmation emits info AuthFailure', () async {
      mockRepo.requireEmailConfirmation = true;
      final bloc = agrinova_auth.AuthBloc(authRepository: mockRepo);

      final expectedStates = [
        isA<agrinova_auth.AuthLoading>(),
        predicate<agrinova_auth.AuthState>((state) =>
            state is agrinova_auth.AuthFailure &&
            state.isInfo == true &&
            state.message.contains('konfirmasi akun')),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(const agrinova_auth.AuthSignUpRequested(
        email: 'newuser@example.com',
        password: 'password123',
        fullName: 'Petani Baru',
      ));
    });

    test('ResetPassword requested emits AuthLoading then AuthResetPasswordSent', () async {
      final bloc = agrinova_auth.AuthBloc(authRepository: mockRepo);

      final expectedStates = [
        isA<agrinova_auth.AuthLoading>(),
        isA<agrinova_auth.AuthResetPasswordSent>(),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(const agrinova_auth.AuthResetPasswordRequested(email: 'user@example.com'));
    });
  });
}
