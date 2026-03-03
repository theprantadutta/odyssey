import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notification_preference_model.g.dart';

@JsonSerializable()
class NotificationPreferenceModel extends Equatable {
  @JsonKey(name: 'invites_and_sharing')
  final bool invitesAndSharing;
  @JsonKey(name: 'content_updates')
  final bool contentUpdates;
  @JsonKey(name: 'trip_reminders')
  final bool tripReminders;
  final bool achievements;
  @JsonKey(name: 'quiet_hours_enabled')
  final bool quietHoursEnabled;
  @JsonKey(name: 'quiet_hours_start')
  final String? quietHoursStart;
  @JsonKey(name: 'quiet_hours_end')
  final String? quietHoursEnd;
  @JsonKey(name: 'quiet_hours_time_zone')
  final String? quietHoursTimeZone;

  const NotificationPreferenceModel({
    this.invitesAndSharing = true,
    this.contentUpdates = true,
    this.tripReminders = true,
    this.achievements = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.quietHoursTimeZone,
  });

  factory NotificationPreferenceModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferenceModelFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationPreferenceModelToJson(this);

  NotificationPreferenceModel copyWith({
    bool? invitesAndSharing,
    bool? contentUpdates,
    bool? tripReminders,
    bool? achievements,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    String? quietHoursTimeZone,
  }) {
    return NotificationPreferenceModel(
      invitesAndSharing: invitesAndSharing ?? this.invitesAndSharing,
      contentUpdates: contentUpdates ?? this.contentUpdates,
      tripReminders: tripReminders ?? this.tripReminders,
      achievements: achievements ?? this.achievements,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      quietHoursTimeZone: quietHoursTimeZone ?? this.quietHoursTimeZone,
    );
  }

  @override
  List<Object?> get props => [
        invitesAndSharing,
        contentUpdates,
        tripReminders,
        achievements,
        quietHoursEnabled,
        quietHoursStart,
        quietHoursEnd,
        quietHoursTimeZone,
      ];
}
