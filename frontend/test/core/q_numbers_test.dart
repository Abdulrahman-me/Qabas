import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/l10n/q_numbers.dart';
import 'package:qabas/l10n/gen/app_localizations_ar.dart';
import 'package:qabas/l10n/gen/app_localizations_en.dart';

void main() {
  test('Arabic digits, decimal separator and prototype rounding', () {
    expect(QNumbers.format(245, 'ar'), '٢٤٥');
    expect(QNumbers.format(-1.25, 'ar_OM'), '-١٫٣');
    expect(QNumbers.format(3.0, 'ar'), '٣');
    expect(QNumbers.format(3.5, 'en'), '3.5');
    expect(QNumbers.format(120, 'en-US'), '120');
  });
  test('Localized time/date digits preserve punctuation, existing Arabic digits and labels', () {
    expect(QNumbers.localizeDigits('7:00 م', 'ar'), '٧:٠٠ م');
    expect(QNumbers.localizeDigits('07:30', 'ar_OM'), '٠٧:٣٠');
    expect(QNumbers.localizeDigits('أكتوبر 2026', 'ar'), 'أكتوبر ٢٠٢٦');
    expect(QNumbers.localizeDigits('٧:٠٠ م', 'ar'), '٧:٠٠ م');
    expect(QNumbers.localizeDigits('7:00 PM', 'en'), '7:00 PM');
  });
  test('parameterized strings preserve the prototype branches and formatted digits', () {
    final ar = AppLocalizationsAr();
    final en = AppLocalizationsEn();
    expect(ar.commonDayStreak(1, '١'), '١ يوم متتالية');
    expect(ar.commonDayStreak(2, '٢'), '٢ يومان متتالية');
    expect(ar.commonDayStreak(3, '٣'), '٣ أيام متتالية');
    expect(ar.commonDayStreak(11, '١١'), '١١ يومًا متتالية');
    expect(ar.commonDayStreak(QNumbers.prototypePluralCount(103), '١٠٣'), '١٠٣ يومًا متتالية');
    expect(ar.commonDays(2, '٢'), '٢ أيام');
    expect(ar.commonMinutesLong(5, '٥'), '٥ دقائق');
    expect(ar.commonMinutesLong(15, '١٥'), '١٥ دقيقة');
    expect(ar.onboardingPerDay(20, '٢٠'), '٢٠ دقيقة يوميًا');
    expect(en.commonDays(1, '1'), '1 day');
    expect(en.commonDays(2, '2'), '2 days');
  });
}
