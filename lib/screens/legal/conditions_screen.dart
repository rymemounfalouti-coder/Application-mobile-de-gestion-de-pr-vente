import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class ConditionsScreen extends StatelessWidget {
  ConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalPage(
      title: AppLocalizations.globalText("Conditions d'utilisation"),
      content:
          "En utilisant PréVente, vous acceptez d'utiliser l'application de "
          "manière responsable pour gérer vos clients, produits, commandes et "
          "factures. Les informations saisies doivent être exactes et vous "
          "restez responsable de la confidentialité de votre compte.",
    );
  }
}

class _LegalPage extends StatelessWidget {
  _LegalPage({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3F7FF),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF111B3D),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  content,
                  style: TextStyle(
                    color: Color(0xFF43516B),
                    fontSize: 16,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
