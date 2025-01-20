import 'dart:io';

import 'package:http/http.dart';

/// Normal client with proxy support
class _ProxyHttpClient extends BaseClient {
  final HttpClient _httpClient;
  final Client _client;

  _ProxyHttpClient(String proxyUrl)
      : _httpClient = HttpClient(),
        _client = Client() {
    _httpClient.findProxy = (uri) {
      return "PROXY $proxyUrl";
    };
    // Override to allow bad certificates
    _httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      return true;
    };
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    return _client.send(request);
  }
}

String findFastestProxy() {
  throw UnimplementedError();
}

String findRandomProxy() {
  throw UnimplementedError();
}

Client getHttpClient(String? proxy) {
  if (proxy != null && proxy.isNotEmpty) {
    return _ProxyHttpClient(proxy);
  } else {
    // return a normal non-proxied client
    return Client();
  }
}
