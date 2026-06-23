import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../database/database_helper.dart';
import '../invoice/invoice_screen.dart';

class ClientInvoicesScreen extends StatefulWidget {
  final int clientId;

  ClientInvoicesScreen({super.key, required this.clientId});

  @override
  State<ClientInvoicesScreen> createState() => _ClientInvoicesScreenState();
}

class _ClientInvoicesScreenState extends State<ClientInvoicesScreen> {
  List invoices = [];

  @override
  void initState() {
    super.initState();
    loadInvoices();
  }

  void loadInvoices() async {
    final db = await DatabaseHelper.instance.database;

    final data = await db.query(
      'factures',
      where: 'id_client = ?',
      whereArgs: [widget.clientId],
      orderBy: 'id DESC',
    );

    setState(() {
      invoices = data;
    });
  }

  void openInvoice(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoiceScreen(factureId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.globalText("Factures Client")),
      ),
      body: ListView.builder(
        itemCount: invoices.length,
        itemBuilder: (context, index) {
          final f = invoices[index];

          return Card(
            child: ListTile(
              title: Text("Facture #${f['id']}"),
              subtitle: Text("Total: ${f['total']} DH"),
              trailing: Icon(Icons.arrow_forward),
              onTap: () => openInvoice(f['id']),
            ),
          );
        },
      ),
    );
  }
}
