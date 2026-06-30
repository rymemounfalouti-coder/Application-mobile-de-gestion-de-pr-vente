import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';

import '../data/mock_presales_data.dart';

class PasswordResetException implements Exception {
  const PasswordResetException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PasswordResetService {
  const PasswordResetService._();

  static final Map<String, _ResetOtp> _otps = {};
  static final Map<String, String> _passwordOverrides = {};
  static final Random _random = Random.secure();

  static String passwordFor(String email, String fallbackPassword) {
    return _passwordOverrides[email.trim().toLowerCase()] ?? fallbackPassword;
  }

  static Future<void> forgotPassword(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final user = MockPreSalesData.userByEmail(normalizedEmail);
    if (user == null) {
      throw const PasswordResetException(
        'Aucun compte PreSales ne correspond a cette adresse.',
      );
    }

    final code = (_random.nextInt(900000) + 100000).toString();
    _otps[normalizedEmail] = _ResetOtp(
      code: code,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );

    final config = await _SmtpConfig.load();
    await _SmtpMailer(config).send(
      to: config.recoveryEmail,
      subject: 'Code de reinitialisation PreSales',
      body:
          'Votre code de verification est : $code\n\n'
          'Ce code expire dans 10 minutes.\n'
          'Compte PreSales concerne : $normalizedEmail',
    );
  }

  static void verifyResetCode({required String email, required String code}) {
    _validateCode(email: email, code: code);
  }

  static void resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    if (newPassword.length < 8) {
      throw const PasswordResetException('Mot de passe trop court.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    _validateCode(email: normalizedEmail, code: code);
    _passwordOverrides[normalizedEmail] = newPassword;
    _otps.remove(normalizedEmail);
  }

  static void _validateCode({required String email, required String code}) {
    final normalizedEmail = email.trim().toLowerCase();
    final otp = _otps[normalizedEmail];
    if (otp == null || otp.code != code.trim()) {
      throw const PasswordResetException('Code de verification incorrect.');
    }
    if (DateTime.now().isAfter(otp.expiresAt)) {
      _otps.remove(normalizedEmail);
      throw const PasswordResetException(
        'Code expire. Veuillez demander un nouveau code.',
      );
    }
  }
}

class _ResetOtp {
  const _ResetOtp({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

class _SmtpConfig {
  const _SmtpConfig({
    required this.host,
    required this.port,
    required this.user,
    required this.password,
    required this.from,
    required this.recoveryEmail,
  });

  final String host;
  final int port;
  final String user;
  final String password;
  final String from;
  final String recoveryEmail;

  static Future<_SmtpConfig> load() async {
    final env = await _loadEnv();

    String requiredValue(String key) {
      final value = env[key]?.trim() ?? '';
      if (value.isEmpty || value.startsWith('mon_')) {
        throw PasswordResetException(
          'Configuration SMTP manquante : renseignez $key dans le fichier .env.',
        );
      }
      return value;
    }

    return _SmtpConfig(
      host: requiredValue('SMTP_HOST'),
      port: int.tryParse(requiredValue('SMTP_PORT')) ?? 587,
      user: requiredValue('SMTP_USER'),
      password: requiredValue(
        'SMTP_PASSWORD',
      ).replaceAll(RegExp(r'\s+'), '').replaceAll('"', '').replaceAll("'", ''),
      from: requiredValue('SMTP_FROM'),
      recoveryEmail: requiredValue('MY_RECOVERY_EMAIL'),
    );
  }

  static Future<Map<String, String>> _loadEnv() async {
    final candidates = [
      File('.env'),
      File('${Directory.current.path}${Platform.pathSeparator}.env'),
    ];

    for (final file in candidates) {
      if (!await file.exists()) continue;
      final lines = await file.readAsLines();
      return _parseEnvLines(lines);
    }

    try {
      final assetContent = await rootBundle.loadString('.env');
      return _parseEnvLines(const LineSplitter().convert(assetContent));
    } catch (_) {
      throw const PasswordResetException(
        'Fichier .env introuvable. Ajoutez la configuration SMTP a la racine du projet.',
      );
    }
  }

  static Map<String, String> _parseEnvLines(List<String> lines) {
    return {
      for (final line in lines)
        if (line.trim().isNotEmpty &&
            !line.trimLeft().startsWith('#') &&
            line.contains('='))
          line.split('=').first.trim(): line
              .substring(line.indexOf('=') + 1)
              .trim(),
    };
  }
}

class _SmtpMailer {
  const _SmtpMailer(this.config);

  final _SmtpConfig config;

  Future<void> send({
    required String to,
    required String subject,
    required String body,
  }) async {
    final server = SmtpServer(
      config.host,
      port: config.port,
      username: config.user,
      password: config.password,
      ssl: false,
      allowInsecure: false,
    );

    final message = mailer.Message()
      ..from = mailer.Address(config.from, 'PreSales')
      ..recipients.add(to)
      ..subject = subject
      ..text = body;

    try {
      await mailer.send(message, server);
    } on mailer.MailerException catch (error) {
      final details = error.problems.map((problem) => problem.msg).join(' ');
      throw PasswordResetException(
        details.isEmpty
            ? 'Erreur SMTP Gmail. Verifiez le mot de passe d application.'
            : 'Erreur SMTP Gmail : $details',
      );
    } catch (_) {
      throw const PasswordResetException(
        'Impossible d envoyer le code. Verifiez la connexion et la configuration SMTP.',
      );
    }
  }
}
