// The mobile Drive transport carries an access token it can renew, instead
// of the one fixed at sign-in that stops working after about an hour.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:finance_copilot/services/sync/mobile_drive_client.dart';

class _Tokens implements DriveTokenSource {
  _Tokens(this._next);

  final List<String?> _next;
  final discarded = <String>[];

  @override
  Future<String?> fetch() async => _next.isEmpty ? null : _next.removeAt(0);

  @override
  Future<void> discard(String token) async => discarded.add(token);
}

/// A transport that only records being closed.
class _Transport extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => throw UnimplementedError();

  @override
  void close() => closed = true;
}

void main() {
  final seen = <String?>[];
  final echo = MockClient((request) async {
    seen.add(request.headers['Authorization']);
    return http.Response('ok', 200);
  });

  setUp(seen.clear);

  test('each request carries the current token, renewed by refresh', () async {
    final client = MobileDriveClient(_Tokens(['renewed']), token: 'at-sign-in', inner: echo);

    await client.get(Uri.parse('https://example.com/a'));
    expect(await client.refresh(), isTrue);
    await client.get(Uri.parse('https://example.com/b'));

    expect(seen, ['Bearer at-sign-in', 'Bearer renewed']);
  });

  test('a refresh Google cannot answer without the user says so, and sends no stale token', () async {
    final client = MobileDriveClient(_Tokens([]), token: 'expired', inner: echo);

    expect(await client.refresh(), isFalse);
    await client.get(Uri.parse('https://example.com/a'));

    expect(seen, [null]);
  });

  test('a rejected token is dropped from the platform cache', () async {
    final tokens = _Tokens([]);
    final client = MobileDriveClient(tokens, token: 'revoked', inner: echo);

    await client.discard();
    await client.get(Uri.parse('https://example.com/a'));

    expect(tokens.discarded, ['revoked']);
    expect(seen, [null]);
  });

  test('renewing the token does not cut a transfer in flight', () async {
    final body = StreamController<List<int>>();
    final slow = MockClient.streaming((request, _) async => http.StreamedResponse(body.stream, 200));
    final client = MobileDriveClient(_Tokens(['renewed']), token: 'first', inner: slow);

    final response = await client.send(http.Request('GET', Uri.parse('https://example.com/download')));
    final received = response.stream.toBytes();
    body.add(utf8.encode('half '));
    expect(await client.refresh(), isTrue);
    body.add(utf8.encode('and the rest'));
    await body.close();

    expect(utf8.decode(await received), 'half and the rest');
  });

  test('closing it closes the connection underneath (sign-out, account swap)', () {
    final transport = _Transport();

    MobileDriveClient(_Tokens([]), inner: transport).close();

    expect(transport.closed, isTrue);
  });
}
