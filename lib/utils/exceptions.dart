class AgeGateException implements Exception {
  @override
  String toString() =>
      "Age gate encountered. Try setting a proxy in settings or using a VPN service.";
}

class BannedCountryException implements Exception {
  @override
  String toString() =>
      "Banned country encountered. Try setting a proxy in settings or using a VPN service.";
}

class UnreachableException implements Exception {
  @override
  String toString() => "Couldn't connect to provider. Try again later.";
}

bool isCustomException(Exception? e) {
  if (e == null) {
    return false;
  }
  return e is AgeGateException ||
      e is BannedCountryException ||
      e is UnreachableException;
}
