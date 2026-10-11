import 'package:spark_sales/core/errors/app_exception.dart';
import 'package:spark_sales/features/sync/domain/sync_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository({this.client});

  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  Session? get currentSession => _supabase.auth.currentSession;

  Future<String> signIn(String email, String password) async {
    try {
      final response = await _supabase.functions.invoke(
        'sign-in-assistant',
        body: {
          'email': email.trim(),
          'password': password,
        },
      );
      final data = response.data;
      final refreshToken = data is Map ? data['refresh_token'] : null;
      final fullName = data is Map ? data['full_name'] : null;
      if (refreshToken is! String ||
          refreshToken.isEmpty ||
          fullName is! String ||
          fullName.trim().isEmpty) {
        throw const AppException(
          'malformed_response',
          'The server returned an unexpected sign-in response.',
          retryable: true,
        );
      }
      await _supabase.auth.setSession(refreshToken);
      return fullName.trim();
    } on FunctionException catch (error) {
      throw SyncErrorMapper.fromStatus(error.status, error.details);
    } on AppException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AppException(
        'network',
        'No network connection. Check the signal and try again.',
        retryable: true,
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut(scope: SignOutScope.global);
    } catch (_) {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    }
  }
}
