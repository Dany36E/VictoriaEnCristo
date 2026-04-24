/// ═══════════════════════════════════════════════════════════════════════════
/// LoadingState - Estado estandarizado para flujos async en UI
/// Úsalo en lugar de booleans sueltos (isLoading, hasError, etc).
/// ═══════════════════════════════════════════════════════════════════════════
library;

enum LoadingStatus { idle, loading, loaded, error }

class LoadingState<T> {
  final LoadingStatus status;
  final T? data;
  final Object? error;
  final StackTrace? stack;

  const LoadingState._({
    required this.status,
    this.data,
    this.error,
    this.stack,
  });

  const LoadingState.idle() : this._(status: LoadingStatus.idle);
  const LoadingState.loading() : this._(status: LoadingStatus.loading);
  const LoadingState.loaded(T value)
      : this._(status: LoadingStatus.loaded, data: value);
  const LoadingState.error(Object e, [StackTrace? s])
      : this._(status: LoadingStatus.error, error: e, stack: s);

  bool get isIdle => status == LoadingStatus.idle;
  bool get isLoading => status == LoadingStatus.loading;
  bool get isLoaded => status == LoadingStatus.loaded;
  bool get isError => status == LoadingStatus.error;

  /// Pattern-match style helper para UI.
  R when<R>({
    required R Function() idle,
    required R Function() loading,
    required R Function(T data) loaded,
    required R Function(Object error, StackTrace? stack) error,
  }) {
    switch (status) {
      case LoadingStatus.idle:
        return idle();
      case LoadingStatus.loading:
        return loading();
      case LoadingStatus.loaded:
        return loaded(data as T);
      case LoadingStatus.error:
        return error(this.error!, stack);
    }
  }
}
