// The phone renews its Drive token through Google Sign-In without the user:
// the backup checks run in the background, so a renewal must never put a
// consent screen in front of them. A token Drive refused is cleared from the
// platform's cache, so the next renewal returns a new one.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

import 'package:finance_copilot/services/sync/mobile_drive_client.dart';

const _scopes = ['https://www.googleapis.com/auth/drive.appdata'];

/// Google Sign-In's platform side: one signed-in user, handed [token].
class _SignInPlatform extends GoogleSignInPlatform {
  String? token;
  final requests = <AuthorizationRequestDetails>[];
  final cleared = <String>[];

  @override
  Future<void> init(InitParameters params) async {}

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(AttemptLightweightAuthenticationParameters params) => null;

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) async => const AuthenticationResults(
    user: GoogleSignInUserData(email: 'me@example.com', id: 'user-1'),
    authenticationTokens: AuthenticationTokenData(idToken: null),
  );

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(ClientAuthorizationTokensForScopesParameters params) async {
    requests.add(params.request);
    final current = token;
    return current == null ? null : ClientAuthorizationTokenData(accessToken: current);
  }

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(ServerAuthorizationTokensForScopesParameters params) async => null;

  @override
  Future<void> clearAuthorizationToken(ClearAuthorizationTokenParams params) async => cleared.add(params.accessToken);

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

void main() {
  final platform = _SignInPlatform();
  late GoogleSignInTokenSource tokens;

  setUpAll(() async {
    GoogleSignInPlatform.instance = platform;
    await GoogleSignIn.instance.initialize();
    tokens = GoogleSignInTokenSource(await GoogleSignIn.instance.authenticate(), _scopes);
  });

  setUp(() {
    platform
      ..token = 'renewed'
      ..requests.clear()
      ..cleared.clear();
  });

  test('a renewal asks for the signed-in account and its scopes, never with a consent screen', () async {
    expect(await tokens.fetch(), 'renewed');

    final request = platform.requests.single;
    expect(request.promptIfUnauthorized, isFalse);
    expect(request.scopes, _scopes);
    expect(request.userId, 'user-1');
    expect(request.email, 'me@example.com');
  });

  test('a renewal only the user can give comes back empty', () async {
    platform.token = null;

    expect(await tokens.fetch(), isNull);
  });

  test('a token Drive refused is cleared from the platform cache', () async {
    await tokens.discard('revoked');

    expect(platform.cleared, ['revoked']);
  });
}
