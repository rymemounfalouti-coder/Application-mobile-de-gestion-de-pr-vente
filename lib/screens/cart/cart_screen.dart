import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../database/database_helper.dart';

class CartScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final int clientId;

  CartScreen({super.key, required this.cartItems, required this.clientId});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double getTotal() {
    double total = 0;
    for (var item in widget.cartItems) {
      total += item['prix'] * item['qte'];
    }
    return total;
  }

  void removeItem(int index) {
    setState(() {
      widget.cartItems.removeAt(index);
    });
  }

  void increaseQty(int index) {
    setState(() {
      widget.cartItems[index]['qte']++;
    });
  }

  void decreaseQty(int index) {
    setState(() {
      if (widget.cartItems[index]['qte'] > 1) {
        widget.cartItems[index]['qte']--;
      }
    });
  }

  void validateOrder() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final db = await DatabaseHelper.instance.database;

    double total = getTotal();

    int factureId = await db.insert('factures', {
      'id_client': widget.clientId,
      'date': DateTime.now().toString(),
      'total': total,
    });

    for (var item in widget.cartItems) {
      await db.insert('details_facture', {
        'id_fact': factureId,
        'id_prod': item['id'],
        'qte': item['qte'],
        'prix_vendu': item['prix'],
      });
    }

    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.globalText("Commande validée ✅")),
      ),
    );

    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    double total = getTotal();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.globalText("Panier")),
        centerTitle: true,
      ),

      body: Column(
        children: [
          Expanded(
            child: widget.cartItems.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.globalText("Panier vide"),
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.cartItems.length,
                    itemBuilder: (context, index) {
                      final item = widget.cartItems[index];

                      return Card(
                        elevation: 4,
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
                            item['nom'],
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("${item['prix']} DH"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => decreaseQty(index),
                                icon: Icon(Icons.remove),
                              ),
                              Text("${item['qte']}"),
                              IconButton(
                                onPressed: () => increaseQty(index),
                                icon: Icon(Icons.add),
                              ),
                              IconButton(
                                onPressed: () => removeItem(index),
                                icon: Icon(Icons.delete, color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 5,
                  offset: Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  "Total : ${total.toStringAsFixed(2)} DH",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.cartItems.isEmpty ? null : validateOrder,
                    icon: Icon(Icons.check),
                    label: Text(
                      AppLocalizations.globalText("Valider la commande"),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
