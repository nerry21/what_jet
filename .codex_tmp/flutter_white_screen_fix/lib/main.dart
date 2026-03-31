import 'dart:async';

import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/routing/app_routes.dart';
import 'core/storage/admin_token_storage.dart';
import 'features/admin_auth/data/models/admin_user_model.dart';
import 'features/admin_auth/data/repositories/admin_auth_repository.dart';
import 'features/admin_auth/data/services/admin_auth_api_service.dart';
import 'features/admin_auth/presentation/pages/admin_login_page.dart';
import 'features/omnichannel/data/repositories/omnichannel_repository.dart';
import 'features/omnichannel/data/services/omnichannel_api_service.dart';
import 'features/omnichannel/presentation/pages/omnichannel_dashboard_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    Zone.current.handleUncaughtError(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  runZonedGuarded(() {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: const Color(0xFFF5F5F5),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Dashboard crash di Flutter',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Buka DevTools browser atau terminal flutter run untuk melihat detail error.',
                        style: TextStyle(fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        details.exceptionAsString(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.red,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    };

    runApp(const WhatsJetApp());
  }, (error, stack) {
    debugPrint('Uncaught Flutter error: $error');
    debugPrintStack(stackTrace: stack);
  });
}

class WhatsJetApp extends StatefulWidget {
  const WhatsJetApp({super.key});

  @override
  State<WhatsJetApp> createState() => _WhatsJetAppState();
}

class _WhatsJetAppState extends State<WhatsJetApp> {
  late final ApiClient _apiClient;
  late final AdminAuthRepository _adminAuthRepository;
  late final OmnichannelRepository _omnichannelRepository;
  late final String _initialRoute;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _adminAuthRepository = AdminAuthRepository(
      authApiService: AdminAuthApiService(_apiClient),
      tokenStorage: AdminTokenStorage(),
    );
    _omnichannelRepository = OmnichannelRepository(
      apiService: OmnichannelApiService(_apiClient),
      adminAuthRepository: _adminAuthRepository,
    );
    _initialRoute = AppRoutes.normalize(
      WidgetsBinding.instance.platformDispatcher.defaultRouteName,
    );
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appTitle,
      theme: AppConfig.theme(),
      initialRoute: _initialRoute,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final routeName = AppRoutes.normalize(settings.name);

    return MaterialPageRoute<void>(
      settings: RouteSettings(name: routeName, arguments: settings.arguments),
      builder: (context) {
        switch (routeName) {
          case AppRoutes.home:
          case AppRoutes.adminLogin:
            return AdminLoginPage(repository: _adminAuthRepository);
          case AppRoutes.adminOmnichannel:
            return OmnichannelDashboardPage(
              repository: _omnichannelRepository,
              adminAuthRepository: _adminAuthRepository,
              initialUser: settings.arguments is AdminUserModel
                  ? settings.arguments as AdminUserModel
                  : null,
            );
          default:
            return AdminLoginPage(repository: _adminAuthRepository);
        }
      },
    );
  }
}
