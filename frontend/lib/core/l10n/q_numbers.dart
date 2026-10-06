abstract final class QNumbers {
  /// Prototype copy branches at 10 rather than repeating every 100 in Arabic.
  /// Use this selector for dayStreak, days, minutesLong, perDay and streakTitle;
  /// the displayed countText/value always retains the original number.
  static num prototypePluralCount(num value) => value > 10 ? 11 : value;

  /// Matches the prototype: integers stay whole, other numbers use one decimal.
  static String format(num value, String locale) {
    final text = value is int ? '$value' : value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
    if (locale.split(RegExp('[-_]')).first != 'ar') return text;
    return localizeDigits(text, locale).replaceAll('.', '٫');
  }

  /// Localized time/date formatters can retain Latin digits; preserve their punctuation and labels.
  static String localizeDigits(String text, String locale) {
    if (locale.split(RegExp('[-_]')).first != 'ar') return text;
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return text.replaceAllMapped(RegExp(r'[0-9]'), (match) => digits[int.parse(match[0]!)]);
  }
}
