import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'user_model.g.dart';

/// User model matching backend schema
@JsonSerializable()
class UserModel extends Equatable {
  final String id;
  final String email;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'display_name')
  final String? displayName;

  /// The account's picture, as the identity provider gave it.
  ///
  /// Set when signing in with Google or Apple; null for an email account. The
  /// backend has always recorded it - the app simply dropped it on the way in,
  /// so every avatar fell back to an initial.
  @JsonKey(name: 'photo_url')
  final String? photoUrl;

  const UserModel({
    required this.id,
    required this.email,
    required this.isActive,
    this.displayName,
    this.photoUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  @override
  List<Object?> get props => [id, email, isActive, displayName, photoUrl];
}

/// Login request
@JsonSerializable(createFactory: false)
class AuthRequest {
  final String email;
  final String password;

  const AuthRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => _$AuthRequestToJson(this);
}

/// Register request (with optional name)
@JsonSerializable(createFactory: false)
class RegisterRequest {
  final String email;
  final String password;
  @JsonKey(name: 'display_name')
  final String? displayName;

  const RegisterRequest({
    required this.email,
    required this.password,
    this.displayName,
  });

  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}

/// Login/Register response
@JsonSerializable()
class AuthResponse extends Equatable {
  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'refresh_token')
  final String refreshToken;
  @JsonKey(name: 'token_type')
  final String tokenType;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'expires_in')
  final int expiresIn; // Access token expiry in seconds

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.userId,
    required this.expiresIn,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);

  @override
  List<Object?> get props => [accessToken, refreshToken, tokenType, userId, expiresIn];
}
