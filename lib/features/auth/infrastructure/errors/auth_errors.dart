

class ConnectionTimeout implements Exception {
  final String message;
  ConnectionTimeout([this.message = 'El servidor tardó demasiado en responder']);
  @override
  String toString() => message;
}

class InvalidToken implements Exception {
  final String message;
  InvalidToken([this.message = 'Sesión expirada o token inválido']);
  @override
  String toString() => message;
}

class WrongCredentials implements Exception {
  final String message;
  WrongCredentials([this.message = 'Usuario o contraseña incorrectos']);
  @override
  String toString() => message;
}

class CustomError implements Exception {
  final String message;
  CustomError(this.message);
  
  @override
  String toString() => message;
}

