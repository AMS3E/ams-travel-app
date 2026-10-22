/// For the optional parts of a page: a failed call shows nothing there
/// instead of failing the whole page.
extension Fallback<T> on Future<T> {
  /// This future's value, or [fallback] when it fails.
  Future<T> or(T fallback) => then((v) => v, onError: (_) => fallback);

  /// This future's value, or null when it fails.
  Future<T?> get orNull => then<T?>((v) => v, onError: (_) => null);
}
