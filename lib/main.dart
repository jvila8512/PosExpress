import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etecsa/config/config.dart';
import 'package:etecsa/config/theme/theme_preferences.dart';
import 'package:etecsa/config/theme/theme_provider.dart';
import 'package:etecsa/features/sms/infrastructure/services/broadcast_receiver.dart';
import 'package:etecsa/features/sms/infrastructure/services/sms_service.dart';
import 'package:telephony_sdt/telephony.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forzar portrait en toda la app (es un POS, no necesita landscape)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  try {
    await Environment.initEnvironment();
  } catch (e) {
    debugPrint('Error initEnvironment: $e');
  }
  
  // Inicializar SMS BroadcastReceiver
  _initSmsReceiver();

  // Seed la preferencia de tema persistida antes del primer frame:
  // evita el flash del tema incorrecto y alimenta el default del provider.
  try {
    ThemePrefs.initialMode = await ThemePreferenceStore.read();
  } catch (e) {
    debugPrint('Error reading theme preference: $e');
  }

  runApp(
    const ProviderScope(child: MainApp())
  );
}

/// Inicializar el receptor de SMS y solicitar permisos.
void _initSmsReceiver() {
  try {
    final smsService = SmsService();
    final receiver = BroadcastReceiver(smsService);

    receiver.setOnSmsReceived((payload, origin) {
      debugPrint('[SMS] Received ${payload.type} from $origin: ${payload.orderId}');
    });

    // Solicitar permisos y registrar listener
    Telephony.instance.requestPhoneAndSmsPermissions.then((granted) {
      if (granted == true) {
        receiver.register();
        debugPrint('✅ SMS permissions granted, receiver active');
      } else {
        debugPrint('⚠️ SMS permissions not granted');
      }
    });
  } catch (e) {
    debugPrint('Failed to init SMS receiver: $e');
  }
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hamburguesaTheme = ref.watch(hamburguesaThemeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      routerConfig: appRouter,
      theme: hamburguesaTheme.light,
      darkTheme: hamburguesaTheme.dark,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      locale: const Locale('es'),
    );
  }
}