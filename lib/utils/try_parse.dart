/// This function allows to safely set individual values and automatically returns null on any error
T? tryParse<T>(T Function() parser) {
  try {
    return parser();
  } catch (_) {
    return null;
  }
}
