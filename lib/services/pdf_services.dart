import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<Uint8List> generateInvoice(Map facture, List details) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "FACTURE #${facture['id']}",
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),

              pw.SizedBox(height: 10),

              pw.Text("Date: ${facture['date']}"),
              pw.Text("Total: ${facture['total']} DH"),

              pw.Divider(),

              pw.Text("Détails:",
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),

              pw.SizedBox(height: 10),

              ...details.map(
                    (d) => pw.Text(
                  "Produit ID: ${d['id_prod']} | Qté: ${d['qte']} | Prix: ${d['prix_vendu']} DH",
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printInvoice(Map facture, List details) async {
    final pdf = await generateInvoice(facture, details);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf,
    );
  }
}
