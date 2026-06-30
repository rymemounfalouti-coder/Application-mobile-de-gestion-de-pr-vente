import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../database/database_helper.dart';
import '../../services/pdf_services.dart';

class InvoiceScreen extends StatefulWidget {
  final int factureId;

  InvoiceScreen({super.key, required this.factureId});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  Map<String, dynamic>? facture;
  List details = [];

  @override
  void initState() {
    super.initState();
    loadInvoice();
  }

  void loadInvoice() async {
    final db = await DatabaseHelper.instance.database;

    List fact = await db.query(
      'factures',
      where: 'id = ?',
      whereArgs: [widget.factureId],
    );

    List det = await db.query(
      'details_facture',
      where: 'id_fact = ?',
      whereArgs: [widget.factureId],
    );

    setState(() {
      facture = fact.first;
      details = det;
    });
  }

  void exportPdf() {
    PdfService.printInvoice(facture!, details);
  }

  @override
  Widget build(BuildContext context) {
    if (facture == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.globalText("Facture")),
        centerTitle: true,
        actions: [
          IconButton(onPressed: exportPdf, icon: Icon(Icons.picture_as_pdf)),
        ],
      ),

      body: Column(
        children: [
          // HEADER FACTURE (UI PRO)
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(10),
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Facture #${facture!['id']}",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Text("Date: ${facture!['date']}"),
                Text(
                  "Total: ${facture!['total']} DH",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 5),

          Divider(),

          Text(
            AppLocalizations.globalText("Détails de la facture"),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 10),

          Expanded(
            child: details.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.globalText(
                        "Aucun produit dans cette facture",
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: details.length,
                    itemBuilder: (context, index) {
                      final d = details[index];

                      return Card(
                        elevation: 3,
                        margin: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(Icons.shopping_bag),
                          ),
                          title: Text(
                            "Produit ID: ${d['id_prod']}",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "Qté: ${d['qte']} | Prix: ${d['prix_vendu']} DH",
                          ),
                        ),
                      );
                    },
                  ),
          ),

          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10),
            child: ElevatedButton.icon(
              onPressed: exportPdf,
              icon: Icon(Icons.picture_as_pdf),
              label: Text(AppLocalizations.globalText("Exporter PDF")),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
