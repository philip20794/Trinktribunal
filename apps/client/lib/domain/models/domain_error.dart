enum DomainErrorCode {
  invalidConfig('INVALID_CONFIG'),
  invalidName('INVALID_NAME'),
  invalidState('INVALID_STATE'),
  contentExhausted('CONTENT_EXHAUSTED');

  const DomainErrorCode(this.value);
  final String value;
}

final class DomainException implements Exception {
  const DomainException(this.code, this.message);
  final DomainErrorCode code;
  final String message;

  @override
  String toString() => '${code.value}: $message';
}
