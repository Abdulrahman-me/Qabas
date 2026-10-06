import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/storage/preferences_store.dart';

enum LocaleStatus { ready, saving, failure }

final class LocaleState extends Equatable {
  const LocaleState(this.language, {this.status = LocaleStatus.ready});
  final String language;
  final LocaleStatus status;
  @override
  List<Object?> get props => [language, status];
}

final class LocaleCubit extends Cubit<LocaleState> {
  LocaleCubit(this._store) : super(LocaleState(_store.string('language') == 'ar' ? 'ar' : 'en'));
  final PreferencesStore _store;
  Future<void> _writes = Future.value();
  int _revision = 0;
  Future<void> languageChanged(String language) async {
    if (!['en', 'ar'].contains(language)) return;
    final revision = ++_revision;
    emit(LocaleState(language, status: LocaleStatus.saving));
    return _writes = _writes.then((_) async {
      try {
        await _store.setString('language', language);
        if (!isClosed && revision == _revision) emit(LocaleState(language));
      } catch (_) {
        if (!isClosed && revision == _revision) emit(LocaleState(language, status: LocaleStatus.failure));
      }
    });
  }
}
