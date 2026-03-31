class AppRoutes {
  const AppRoutes._();

  static const String home = '/';
  static const String adminLogin = '/admin/login';
  static const String adminOmnichannel = '/admin/omnichannel';

  static bool isKnown(String? routeName) {
    return switch (routeName) {
      home || adminLogin || adminOmnichannel => true,
      _ => false,
    };
  }

  static String normalize(String? routeName) {
    if (isKnown(routeName)) {
      return routeName!;
    }

    return home;
  }
}
