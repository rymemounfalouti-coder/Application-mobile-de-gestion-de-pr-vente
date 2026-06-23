import '../data/mock_presales_data.dart';

enum AppThemePreference { light, dark, system }

enum AppTextSizePreference { small, medium, large }

class AuthenticatedUser {
  AuthenticatedUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.phone = '',
    this.theme = AppThemePreference.system,
    this.textSize = AppTextSizePreference.medium,
    this.autoBrightness = true,
    this.powerSavingMode = false,
  });

  factory AuthenticatedUser.fromMock(MockUserProfile user) {
    return AuthenticatedUser(
      id: user.id,
      fullName: user.name,
      email: user.email,
      role: user.role,
      phone: user.phone,
    );
  }

  final int id;
  final String fullName;
  final String email;
  final MockUserRole role;
  final String phone;
  AppThemePreference theme;
  AppTextSizePreference textSize;
  bool autoBrightness;
  bool powerSavingMode;

  bool get isCommercial => role == MockUserRole.commercial;
  bool get isManager => role == MockUserRole.manager;
  bool get isAdmin => role == MockUserRole.admin;
}

class CurrentUserSession {
  const CurrentUserSession._();

  static AuthenticatedUser? currentUser;

  static void signIn(AuthenticatedUser user) {
    currentUser = user;
  }

  static void signOut() {
    currentUser = null;
  }
}
