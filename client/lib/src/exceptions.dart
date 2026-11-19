sealed class RegistryException implements Exception {
  const RegistryException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class CertificatePinException extends RegistryException {
  const CertificatePinException(super.message);
}

class ProtocolException extends RegistryException {
  const ProtocolException(super.message);
}

class BlobAuthenticityException extends RegistryException {
  const BlobAuthenticityException(super.message);
}

class BlobStaleException extends RegistryException {
  const BlobStaleException(super.message);
}

class ServerErrorException extends RegistryException {
  const ServerErrorException(this.token, super.message);

  final String token;
}

class UnauthenticatedException extends ServerErrorException {
  const UnauthenticatedException(super.token, super.message);
}

class AlreadyAuthenticatedException extends ServerErrorException {
  const AlreadyAuthenticatedException(super.token, super.message);
}

class UnknownCommandException extends ServerErrorException {
  const UnknownCommandException(super.token, super.message);
}

class UsageException extends ServerErrorException {
  const UsageException(super.token, super.message);
}

class BadKeyException extends ServerErrorException {
  const BadKeyException(super.token, super.message);
}

class NoChallengeException extends ServerErrorException {
  const NoChallengeException(super.token, super.message);
}

class StaleChallengeException extends ServerErrorException {
  const StaleChallengeException(super.token, super.message);
}

class BadSignatureException extends ServerErrorException {
  const BadSignatureException(super.token, super.message);
}

class BadIdException extends ServerErrorException {
  const BadIdException(super.token, super.message);
}

class BadBlobException extends ServerErrorException {
  const BadBlobException(super.token, super.message);
}

class BlobTooLargeException extends ServerErrorException {
  const BlobTooLargeException(super.token, super.message);
}

class TooManyRecipientsException extends ServerErrorException {
  const TooManyRecipientsException(super.token, super.message);
}

class TooManyHandshakesException extends ServerErrorException {
  const TooManyHandshakesException(super.token, super.message);
}

class InternalServerException extends ServerErrorException {
  const InternalServerException(super.token, super.message);
}

ServerErrorException serverErrorFrom(String line) {
  final rest = line.length > 4 ? line.substring(4) : '';
  final token = rest.split(' ').first;

  return switch (token) {
    'unauthenticated' => UnauthenticatedException(token, rest),
    'already-authenticated' => AlreadyAuthenticatedException(token, rest),
    'unknown-command' => UnknownCommandException(token, rest),
    'usage' => UsageException(token, rest),
    'bad-key' => BadKeyException(token, rest),
    'no-challenge' => NoChallengeException(token, rest),
    'stale-challenge' => StaleChallengeException(token, rest),
    'bad-signature' => BadSignatureException(token, rest),
    'bad-id' => BadIdException(token, rest),
    'bad-blob' => BadBlobException(token, rest),
    'blob-too-large' => BlobTooLargeException(token, rest),
    'too-many-recipients' => TooManyRecipientsException(token, rest),
    'too-many-handshakes' => TooManyHandshakesException(token, rest),
    'internal' => InternalServerException(token, rest),
    _ => ServerErrorException(token, rest),
  };
}
