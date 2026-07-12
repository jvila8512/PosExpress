import 'package:etecsa/features/auth/presentation/providers/auth_provider.dart';
import 'package:etecsa/features/shared/infrastructure/inputs/email.dart';
import 'package:etecsa/features/shared/infrastructure/inputs/password.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formz/formz.dart';

final loginFormProvider =
    NotifierProvider.autoDispose<LoginFormNotifier, LoginFormState>(LoginFormNotifier.new);

class LoginFormNotifier extends Notifier<LoginFormState> {
  Function(String, String, bool)? _loginUserCallback;

  @override
  LoginFormState build() {
    _loginUserCallback = ref.watch(authProvider.notifier).loginUser;
    return LoginFormState();
  }

  void onEmailChange(String value) {
    final newEmail = Email.dirty(value);
    state = state.copyWith(
      email: newEmail,
      isValid: Formz.validate([newEmail, state.password]),
    );
    _clearErrorIfNeeded();
  }

  void onPasswordChanged(String value) {
    final newPassword = Password.dirty(value);
    state = state.copyWith(
      password: newPassword,
      isValid: Formz.validate([newPassword, state.email]),
    );
    _clearErrorIfNeeded();
  }

  void _clearErrorIfNeeded() {
    final authState = ref.read(authProvider);
    if (authState.errorMessage.isNotEmpty) {
      ref.read(authProvider.notifier).clearError();
    }
  }

  Future<void> onFormSubmit() async {
    _touchEveryField();

    if (!state.isValid) return;
    if (_loginUserCallback == null) return;

    await _loginUserCallback!(state.email.value, state.password.value, state.rememberMe);
  }

  void _touchEveryField() {
    final email = Email.dirty(state.email.value);
    final password = Password.dirty(state.password.value);

    state = state.copyWith(
      isFormPosted: true,
      email: email,
      password: password,
      isValid: Formz.validate([email, password]),
    );
  }

  void onRememberMeChanged(bool value) {
    state = state.copyWith(rememberMe: value);
  }

  void togglePasswordVisibility() {
    state = state.copyWith(isPasswordVisible: !state.isPasswordVisible);
  }
}

class LoginFormState {
  final bool isPosting;
  final bool isFormPosted;
  final bool isValid;
  final Email email;
  final Password password;
  final bool rememberMe;
  final bool isPasswordVisible;

  LoginFormState({
    this.isPosting = false,
    this.isFormPosted = false,
    this.isValid = false,
    this.rememberMe = false,
    this.isPasswordVisible = false,
    this.email = const Email.pure(),
    this.password = const Password.pure(),
  });

  LoginFormState copyWith({
    bool? isPosting,
    bool? isFormPosted,
    bool? isValid,
    bool? rememberMe,
    Email? email,
    bool? isPasswordVisible,
    Password? password,
  }) => LoginFormState(
    isPosting: isPosting ?? this.isPosting,
    isFormPosted: isFormPosted ?? this.isFormPosted,
    isValid: isValid ?? this.isValid,
    rememberMe: rememberMe ?? this.rememberMe,
    email: email ?? this.email,
    password: password ?? this.password,
    isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
  );
}