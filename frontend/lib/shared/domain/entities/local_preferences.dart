import 'package:equatable/equatable.dart';

final class LocalPreferences extends Equatable {
  const LocalPreferences({
    this.sound = true,
    this.haptics = true,
    this.reduceMotion = false,
    this.discreetReminders = false,
    this.companionEnabled = true,
    this.reminderHour = 19,
  });
  final bool sound, haptics, reduceMotion, discreetReminders, companionEnabled;
  final int reminderHour;
  LocalPreferences copyWith({
    bool? sound,
    bool? haptics,
    bool? reduceMotion,
    bool? discreetReminders,
    bool? companionEnabled,
    int? reminderHour,
  }) => LocalPreferences(
    sound: sound ?? this.sound,
    haptics: haptics ?? this.haptics,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    discreetReminders: discreetReminders ?? this.discreetReminders,
    companionEnabled: companionEnabled ?? this.companionEnabled,
    reminderHour: reminderHour ?? this.reminderHour,
  );
  @override
  List<Object?> get props => [sound, haptics, reduceMotion, discreetReminders, companionEnabled, reminderHour];
}
