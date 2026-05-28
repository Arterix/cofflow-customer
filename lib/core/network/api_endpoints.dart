class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Menu (public)
  static const String menus = '/menus';
  static const String categories = '/categories';
  static String menuDetail(int id) => '/menus/$id';

  // Orders
  static const String orders = '/orders';
  static String orderDetail(int id) => '/orders/$id';
  static String orderPaymentStatus(int id) => '/orders/$id/payment-status';
  static String cancelOrder(int id) => '/orders/$id';
}
