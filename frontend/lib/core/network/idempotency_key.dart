import 'package:uuid/uuid.dart';

/// Create in the BLoC once per user action; keep it for automatic retries.
String newIdempotencyKey() => const Uuid().v4();
