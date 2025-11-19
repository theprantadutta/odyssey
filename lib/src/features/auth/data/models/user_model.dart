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

  const UserModel({
    required this.id,
    required this.email,
    required this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  @override
  List<Object?> get props => [id, email, isActive];
}

/// Login/Register request
@JsonSerializable()
class AuthRequest {
  final String email;
  final String password;

  const AuthRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => _$AuthRequestToJson(this);
}

/// Login/Register response
@JsonSerializable()
class AuthResponse extends Equatable {
  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'token_type')
  final String tokenType;
  @JsonKey(name: 'user_id')
  final String userId;

  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.userId,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);

  @override
  List<Object?> get props => [accessToken, tokenType, userId];
}
