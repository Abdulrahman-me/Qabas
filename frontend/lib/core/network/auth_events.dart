sealed class AuthEvent {
  const AuthEvent();
}

final class AuthExpired extends AuthEvent {
  const AuthExpired();
}

final class ClientOutdated extends AuthEvent {
  const ClientOutdated(this.minimumVersion);
  final String? minimumVersion;
}

/// An admin request was refused; reload the server role without discarding a learner credential.
final class ReviewerAccessForbidden extends AuthEvent {
  const ReviewerAccessForbidden();
}
