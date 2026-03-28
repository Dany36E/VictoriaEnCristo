/// Tipo Result para manejo de errores sin excepciones.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
        Success(value: final v) => v,
        Failure() => null,
      };

  String? get errorOrNull => switch (this) {
        Success() => null,
        Failure(message: final m) => m,
      };

  /// Transforma el valor en caso de éxito.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success(value: final v) => Success(transform(v)),
        Failure(message: final m, :final error, :final stackTrace) =>
          Failure(m, error: error, stackTrace: stackTrace),
      };

  /// Ejecuta [onSuccess] o [onFailure] según el caso.
  R when<R>({
    required R Function(T value) success,
    required R Function(String message, Object? error) failure,
  }) =>
      switch (this) {
        Success(value: final v) => success(v),
        Failure(message: final m, :final error) => failure(m, error),
      };

  /// Devuelve el valor o un fallback.
  T getOrElse(T Function() fallback) => switch (this) {
        Success(value: final v) => v,
        Failure() => fallback(),
      };
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class Failure<T> extends Result<T> {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  const Failure(this.message, {this.error, this.stackTrace});
}
