enum ViewStatus {
  initial,
  loading,
  data,
  empty,
  error,
  unavailable,
}

class ViewState<T> {
  const ViewState._({
    required this.status,
    this.data,
    this.message,
  });

  final ViewStatus status;
  final T? data;
  final String? message;

  bool get hasData => status == ViewStatus.data && data != null;

  static ViewState<T> initial<T>() => const ViewState._(status: ViewStatus.initial);

  static ViewState<T> loading<T>() => const ViewState._(status: ViewStatus.loading);

  static ViewState<T> ready<T>(T data) =>
      ViewState._(status: ViewStatus.data, data: data);

  static ViewState<T> empty<T>(String message) =>
      ViewState._(status: ViewStatus.empty, message: message);

  static ViewState<T> error<T>(String message) =>
      ViewState._(status: ViewStatus.error, message: message);

  static ViewState<T> unavailable<T>(String message) =>
      ViewState._(status: ViewStatus.unavailable, message: message);
}
