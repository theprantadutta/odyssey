/// What is known about an account's entitlement.
///
/// Three states, not two. The distinction between *unknown* and *free* is the
/// whole reason this type exists: they used to be the same value, because
/// entitlement was read as `status?.isPremium ?? false`. During startup — and
/// after any failure to load — a paying subscriber was therefore treated as a
/// free user, and shown ads they had paid not to see.
enum Entitlement {
  /// Not established yet, or the last attempt to establish it failed.
  ///
  /// Nothing that depends on the *absence* of Premium may act on this: no ads,
  /// no upsells, no "upgrade to unlock". Things that depend on its presence may
  /// not act on it either.
  unknown,

  /// Established: this account has no subscription.
  free,

  /// Established: this account has Premium.
  premium;

  /// Whether the account is known to be Premium.
  bool get isPremium => this == Entitlement.premium;

  /// Whether the account is known *not* to be Premium.
  ///
  /// Deliberately not `!isPremium`. An unknown entitlement is neither, and the
  /// difference decides whether an ad may be shown.
  bool get isKnownFree => this == Entitlement.free;

  /// Whether the question has been answered at all.
  bool get isResolved => this != Entitlement.unknown;
}
