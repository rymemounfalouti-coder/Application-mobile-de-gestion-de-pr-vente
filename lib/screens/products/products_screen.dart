import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../database/database_helper.dart';

class ProductsScreen extends StatefulWidget {
  final int categoryId;
  final int clientId;

  ProductsScreen({super.key, required this.categoryId, required this.clientId});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> products = [];

  Map<int, int> cart = {};

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  void loadProducts() async {
    final db = await DatabaseHelper.instance.database;

    final data = await db.query(
      'produits',
      where: 'id_cat = ?',
      whereArgs: [widget.categoryId],
    );

    setState(() {
      products = data;
    });
  }

  void addQty(int productId) {
    setState(() {
      cart[productId] = (cart[productId] ?? 0) + 1;
    });
  }

  void removeQty(int productId) {
    setState(() {
      if (cart[productId] != null && cart[productId]! > 0) {
        cart[productId] = cart[productId]! - 1;
      }
    });
  }

  int getTotal() {
    int total = 0;

    for (var p in products) {
      int id = p['id'];
      int qty = cart[id] ?? 0;
      double price = p['prix'];

      total += (price * qty).toInt();
    }

    return total;
  }

  void openCart() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Column(
          children: [
            SizedBox(height: 10),
            Text(
              AppLocalizations.globalText("Panier"),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            Expanded(
              child: ListView(
                children: products.map((p) {
                  int qty = cart[p['id']] ?? 0;

                  if (qty == 0) return SizedBox();

                  return ListTile(
                    title: Text(p['nom_produit']),
                    subtitle: Text("Qté: $qty"),
                    trailing: Text("${p['prix'] * qty} DH"),
                  );
                }).toList(),
              ),
            ),

            Text("Total : ${getTotal()} DH", style: TextStyle(fontSize: 18)),

            SizedBox(height: 10),

            ElevatedButton(
              onPressed: validateOrder,
              child: Text(AppLocalizations.globalText("Valider facture")),
            ),

            TextButton(
              onPressed: () {
                setState(() {
                  cart.clear();
                });
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.globalText("Annuler")),
            ),
          ],
        );
      },
    );
  }

  void validateOrder() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final db = await DatabaseHelper.instance.database;

    int factureId = await db.insert('factures', {
      'id_client': widget.clientId,
      'date': DateTime.now().toString(),
      'total': getTotal(),
    });

    for (final entry in cart.entries) {
      final productId = entry.key;
      final qty = entry.value;
      if (qty > 0) {
        final product = products.firstWhere((p) => p['id'] == productId);

        await db.insert('details_facture', {
          'id_fact': factureId,
          'id_prod': productId,
          'qte': qty,
          'prix_vendu': product['prix'],
        });
      }
    }

    if (!mounted) return;

    setState(() {
      cart.clear();
    });

    navigator.pop();
    navigator.pop();

    messenger.showSnackBar(
      SnackBar(content: Text(AppLocalizations.globalText("Facture créée ✅"))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.globalText("Produits"))),

      // ðŸ›’ bouton panier flottant
      floatingActionButton: FloatingActionButton(
        onPressed: openCart,
        child: Text("${getTotal()}"),
      ),

      body: ListView.builder(
        itemCount: products.length,
        itemBuilder: (context, index) {
          final p = products[index];
          int qty = cart[p['id']] ?? 0;

          return Card(
            child: ListTile(
              title: Text(p['nom_produit']),
              subtitle: Text("${p['prix']} DH"),

              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => removeQty(p['id']),
                    icon: Icon(Icons.remove),
                  ),
                  Text("$qty"),
                  IconButton(
                    onPressed: () => addQty(p['id']),
                    icon: Icon(Icons.add),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
