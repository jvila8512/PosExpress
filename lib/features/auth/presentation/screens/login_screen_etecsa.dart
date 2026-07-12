import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// Mantengo tus imports originales para que no se rompa la lógica
import 'package:etecsa/features/auth/presentation/providers/auth_provider.dart';
import 'package:etecsa/features/auth/presentation/providers/providers.dart';
import 'package:etecsa/features/shared/shared.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Colores extraídos de tu HTML
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F2F5);
    final size = MediaQuery.of(context).size; // Obtén el tamaño de la pantalla
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: bgColor,
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              // 1. Cabecera (Asegúrate de que no tenga un height excesivo)
              _HeaderDesign(isDark: isDark),

              // 2. Contenedor del Formulario
              Container(
                width: double.infinity,
                // ESTA ES LA CLAVE:
                // Usamos el alto total de la pantalla menos el alto aproximado del header
                constraints: BoxConstraints(minHeight: size.height - 240),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                // Usamos IntrinsicHeight para que el contenido interno pueda expandirse
                child: const _LoginForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderDesign extends StatelessWidget {
  final bool isDark;
  const _HeaderDesign({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          // El cuadro azul con sombra del HTML
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF0056B3), // primary color del HTML
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0056B3).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(Icons.shield_sharp, color: Colors.white, size: 45),
          ),
          const SizedBox(height: 20),
          Text(
            'Bienvenido',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF111418),
            ),
          ),
          const Text(
            'Ingresa tus credenciales para continuar',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends ConsumerWidget {
  const _LoginForm();

  void showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Usamos tus proveedores de Riverpod
    final loginForm = ref.watch(loginFormProvider);
    // AGREGA ESTA LÍNEA:
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF0056B3);

    ref.listen(authProvider, (previous, next) {
      if (next.errorMessage.isEmpty) return;
      showSnackbar(context, next.errorMessage);
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Mostrar error solo si existe un mensaje en el estado
          if (authState.errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      authState.errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  // BOTÓN PARA QUE EL USUARIO LO QUITE SI QUIERE
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 18),
                    onPressed: () {
                      ref.read(authProvider.notifier).clearError();
                    },
                  ),
                ],
              ),
            ),
          // Reutilizo tu CustomTextFormField con los datos del provider
          CustomTextFormField(
            label: 'Usuario o Correo',
            keyboardType: TextInputType.emailAddress,
            onChanged: ref.read(loginFormProvider.notifier).onEmailChange,
            errorMessage: loginForm.isFormPosted
                ? loginForm.email.errorMessage
                : null,
          ),

          const SizedBox(height: 25),

          CustomTextFormField(
            label: 'Contraseña',
            obscureText:
                !loginForm.isPasswordVisible, // Si no es visible, ocultar texto
            onChanged: ref.read(loginFormProvider.notifier).onPasswordChanged,
            errorMessage: loginForm.password.errorMessage,
            suffixIcon: IconButton(
              icon: Icon(
                loginForm.isPasswordVisible
                    ? Icons.visibility
                    : Icons.visibility_off,
              ),
              onPressed: () {
                ref.read(loginFormProvider.notifier).togglePasswordVisibility();
              },
            ),
          ),
          CheckboxListTile(
            title: const Text('Recordarme'),
            value: loginForm.rememberMe,
            controlAffinity:
                ListTileControlAffinity.leading, // Pone el check a la izquierda
            activeColor: Colors.blue,
            onChanged: (value) {
              ref
                  .read(loginFormProvider.notifier)
                  .onRememberMeChanged(value ?? false);
            },
          ),

          // Enlace de "¿Olvidaste tu contraseña?" del HTML
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed:
                  () {}, // Aquí puedes añadir la lógica de recuperar pass
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Botón con el color primario del diseño nuevo
          SizedBox(
            width: double.infinity,
            height: 55,
            child: CustomFilledButton(
              text: 'Iniciar Sesión',
              buttonColor: primaryColor,
              onPressed: () {
                ref.read(loginFormProvider.notifier).onFormSubmit();
              },
            ),
          ),

          const SizedBox(height: 30),

          // Texto legal del pie de página del HTML
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Al iniciar sesión, aceptas nuestros Términos y Condiciones y nuestra Política de Privacidad.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ),

          const SizedBox(height: 40),

          // Fila de registro con navegación GoRouter
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '¿No tienes cuenta?',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/register'),
                child: const Text(
                  'Regístrate',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
