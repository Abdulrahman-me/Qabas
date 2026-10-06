import 'package:flutter/widgets.dart';
import 'package:qabas/core/l10n/q_numbers.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';

extension L10nX on BuildContext {
  String n(num value) => QNumbers.format(value, Localizations.localeOf(this).languageCode);
  AppLocalizations get l10n => AppLocalizations.of(this);
  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';
}
