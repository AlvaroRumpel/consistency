class LocalDataException implements Exception {
  final String message;
  final LocalDataErrorType typeError;

  LocalDataException({
    required this.message,
    required this.typeError,
  });
}

enum LocalDataErrorType {
  save(1, 'Error on save'),
  search(2, 'Error on search'),
  generic(3, 'Error generic');

  final int code;
  final String description;

  const LocalDataErrorType(this.code, this.description);
}
