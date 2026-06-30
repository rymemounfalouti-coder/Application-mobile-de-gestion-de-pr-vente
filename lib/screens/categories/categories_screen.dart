import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../database/database_helper.dart';

class CategoriesScreen extends StatefulWidget {
  final int clientId;

  CategoriesScreen({super.key, required this.clientId});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List categories = [];

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  void loadCategories() async {
    final db = await DatabaseHelper.instance.database;
    final data = await db.query('categories');

    setState(() {
      categories = data;
    });
  }

  void openProducts(int categoryId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(AppLocalizations.globalText("Produits"))),
          body: Center(
            child: Text("Client: ${widget.clientId} | Catégorie: $categoryId"),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.globalText("Catégories"))),

      body: GridView.builder(
        padding: EdgeInsets.all(10),
        itemCount: categories.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          final c = categories[index];

          return GestureDetector(
            onTap: () => openProducts(c['id']),
            child: Card(
              elevation: 4,
              child: Center(
                child: Text(c['nom_cat'], style: TextStyle(fontSize: 18)),
              ),
            ),
          );
        },
      ),
    );
  }
}
