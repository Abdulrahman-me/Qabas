abstract final class ReviewerRoutes {
  static const login = '/reviewer/login', runs = '/reviewer/runs', blind = '/reviewer/blind', metrics = '/reviewer/metrics';
  static String run(String id) => '$runs/${Uri.encodeComponent(id)}';
}
