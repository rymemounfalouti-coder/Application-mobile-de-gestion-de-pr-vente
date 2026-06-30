import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../../database/database_helper.dart';
import '../../screens/clients/clients_screen.dart';
import '../../screens/categories/categories_screen.dart';

class DashboardScreen extends StatefulWidget {
  DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int nbClients = 0;
  int nbCategories = 0;
  int nbProducts = 0;
  double totalSales = 0;

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  void loadStats() async {
    final db = await DatabaseHelper.instance.database;

    final clients = await db.rawQuery('SELECT COUNT(*) as count FROM clients');
    final categories = await db.rawQuery(
      'SELECT COUNT(*) as count FROM categories',
    );
    final products = await db.rawQuery(
      'SELECT COUNT(*) as count FROM produits',
    );
    final sales = await db.rawQuery('SELECT SUM(total) as total FROM factures');

    setState(() {
      nbClients = clients.first['count'] as int;
      nbCategories = categories.first['count'] as int;
      nbProducts = products.first['count'] as int;
      totalSales = (sales.first['total'] ?? 0) as double;
    });
  }

  Widget buildCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }

  void goTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.globalText("Dashboard")),
        centerTitle: true,
      ),

      body: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          children: [
            // GRID STATS
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                children: [
                  buildCard("Clients", "$nbClients", Icons.person, Colors.blue),

                  buildCard(
                    "Catégories",
                    "$nbCategories",
                    Icons.category,
                    Colors.orange,
                  ),

                  buildCard(
                    "Produits",
                    "$nbProducts",
                    Icons.shopping_cart,
                    Colors.green,
                  ),

                  buildCard(
                    "Ventes",
                    "${totalSales.toStringAsFixed(2)} DH",
                    Icons.attach_money,
                    Colors.red,
                  ),
                ],
              ),
            ),

            SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => goTo(ClientsScreen()),
                    icon: Icon(Icons.person),
                    label: Text(AppLocalizations.globalText("Clients")),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => goTo(CategoriesScreen(clientId: 0)),
                    icon: Icon(Icons.category),
                    label: Text(AppLocalizations.globalText("Catégories")),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
