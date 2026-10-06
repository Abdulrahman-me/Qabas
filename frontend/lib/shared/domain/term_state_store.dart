import 'package:qabas/shared/domain/entities/content.dart';

abstract interface class TermStateStore {
  Map<String, TermState> get states;
  Stream<Map<String, TermState>> get changes;
  void merge(Map<String, TermCard> terms);
}
