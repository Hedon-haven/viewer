import 'dart:io';

import 'package:http/http.dart';
import 'package:http/io_client.dart';

String findFastestProxy() {
  throw UnimplementedError();
}

String findRandomProxy() {
  throw UnimplementedError();
}

Client getHttpClient(String? proxy) {
  if (proxy != null && proxy.isNotEmpty) {
    final httpClient = HttpClient();
    httpClient.findProxy = (uri) => "PROXY $proxy";
    // Allow bad certificates
    httpClient.badCertificateCallback = (cert, host, port) => true;
    // httpClient.connectionTimeout = Duration(seconds: 5); // Set timeout

    return IOClient(httpClient);
  }
  return Client();
}
