import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:etecsa/config/config.dart';
import 'package:etecsa/config/theme/theme_provider.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/sms/infrastructure/services/broadcast_receiver.dart';
import 'package:etecsa/features/sms/infrastructure/services/sms_service.dart';
import 'package:telephony_sdt/telephony.dart';
import 'package:uuid/uuid.dart';

/// Bandera para crear licencia de prueba al iniciar
/// Cambiar a true solo cuando necesite crear una license de prueba
const bool _CREAR_LICENCIA_PRUEBA = false;

/// Clave de licencia válida para pruebas
/// Hash SHA256("ADMIN-PRO-2027-12-31-PosJVL2024SecretKey1234") = 0A07ABA4
const String _LICENSE_KEY_PRUEBA = 'ADMIN-PRO-2027-12-31-0A07ABA4';

const _storage = FlutterSecureStorage();

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
  
  // Crear licencia de prueba si está habilitada
  if (_CREAR_LICENCIA_PRUEBA) {
    await _crearLicenciaPrueba();
  }

  // Inicializar SMS BroadcastReceiver
  _initSmsReceiver();

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

/// Crear licencia de prueba en la base de datos
Future<void> _crearLicenciaPrueba() async {
  final db = AppDatabase.instance;
  final now = DateTime.now();
  final fechaFin = DateTime(2027, 12, 31);
  final licenseKey = _LICENSE_KEY_PRUEBA;
  
  try {
    await db.createLicense(
      id: const Uuid().v4(),
      licenseKey: licenseKey,
      tipo: 'admin',
      fechaInicio: now,
      fechaFin: fechaFin,
      dispositivoId: '',
    );
    // Guardar en secure storage para que se reconozca como activa
    await _storage.write(key: 'license_key', value: licenseKey);
    await _storage.write(key: 'license_type', value: 'ADMIN');
    debugPrint('✅ Licencia de prueba creada: $licenseKey');
    await Clipboard.setData(ClipboardData(text: licenseKey));
  } catch (e) {
    debugPrint('Info: $e'); // Probably already exists
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