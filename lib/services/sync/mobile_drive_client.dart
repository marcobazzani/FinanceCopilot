import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Where the mobile Drive client gets its access tokens.
abstract interface class DriveTokenSource {
  /// A valid token, without user interaction; null when the user must sign
  /// in again.
  Future<String?> fetch();

  /// Drops [token] from the platform's cache: Drive rejected it.
  Future<void> discard(String token);
}

/// [DriveTokenSource] over a signed-in Google account: Google Sign-In renews
/// the token silently while the user's grant holds.
class GoogleSignInTokenSource implements DriveTokenSource {
  const GoogleSignInTokenSource(this._account, this._scopes);

  final GoogleSignInAccount _account;
  final List<String> _scopes;

  @override
  Future<String?> fetch() async => (await _account.authorizationClient.authorizationForScopes(_scopes))?.accessToken;

  @override
  Future<void> discard(String token) => _account.authorizationClient.clearAuthorizationToken(accessToken: token);
}

/// The Drive transport on Android and iOS. Google Sign-In hands out access
/// tokens that last about an hour and no refresh token, so the token is
/// fetched again before each Drive operation ([refresh]) instead of being
/// fixed at sign-in: a fixed one makes every lookup, backup and restore fail
/// once it expires, until the app restarts. One inner client serves the whole
/// session, so renewing the token never cuts a transfer in flight.
class MobileDriveClient extends http.BaseClient {
  MobileDriveClient(this._tokens, {String? token, http.Client? inner}) : _token = token, _inner = inner ?? http.Client();

  final DriveTokenSource _tokens;
  final http.Client _inner;
  String? _token;

  /// Fetches a valid token; false when Google needs the user to sign in
  /// again.
  Future<bool> refresh() async {
    final token = await _tokens.fetch();
    _token = token;
    return token != null;
  }

  /// Drops the current token after Drive rejected it, so the next [refresh]
  /// gets a new one.
  Future<void> discard() async {
    final token = _token;
    _token = null;
    if (token != null) await _tokens.discard(token);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_token case final token?) request.headers['Authorization'] = 'Bearer $token';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
