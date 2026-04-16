import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_routes.dart';
import 'core/storage/admin_token_storage.dart';
import 'core/services/push_notification_service.dart';
import 'features/admin_auth/data/models/admin_user_model.dart';
import 'features/admin_auth/data/repositories/admin_auth_repository.dart';
import 'features/admin_auth/data/services/admin_auth_api_service.dart';
import 'features/admin_auth/presentation/pages/admin_login_page.dart';
import 'features/omnichannel/data/repositories/omnichannel_repository.dart';
import 'features/omnichannel/data/services/omnichannel_api_service.dart';
import 'features/omnichannel/presentation/pages/omnichannel_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── Firebase Initialization ─────────────────────────────────────────
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotificationService.instance.initialize();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    Zone.current.handleUncaughtError(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  runZonedGuarded(
    () {
      ErrorWidget.builder = (FlutterErrorDetails details) {
        return Material(
          color: const Color(0xFFF5F5F5),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadii.borderRadiusXxl,
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Terjadi error pada tampilan Flutter',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Dashboard berhasil dibuka, tetapi ada widget yang crash saat dirender.',
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Detail error:',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5F5),
                              borderRadius: AppRadii.borderRadiusLg,
                              border: Border.all(
                                color: const Color(0xFFFFD6D6),
                              ),
                            ),
                            child: SelectableText(
                              details.exceptionAsString(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.red,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Lihat juga terminal flutter run atau DevTools browser untuk stack trace lengkap.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      };

      runApp(const WhatsJetApp());
    },
    (error, stack) {
      debugPrint('Uncaught Flutter error: $error');
      debugPrintStack(stackTrace: stack);
    },
  );
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
      theme: AppTheme.light(),
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
