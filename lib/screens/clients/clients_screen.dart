import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../database/database_helper.dart';

class ClientsScreen extends StatefulWidget {
  ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<Map<String, dynamic>> clients = [];

  final nomController = TextEditingController();
  final prenomController = TextEditingController();
  final emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadClients();
  }

  void loadClients() async {
    final db = await DatabaseHelper.instance.database;
    final data = await db.query('clients');

    setState(() {
      clients = data;
    });
  }

  void addClient() async {
    final db = await DatabaseHelper.instance.database;

    await db.insert('clients', {
      'nom_client': nomController.text,
      'prenom_client': prenomController.text,
      'email': emailController.text,
    });

    nomController.clear();
    prenomController.clear();
    emailController.clear();

    loadClients();
  }

  void openHistory(int clientId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.globalText("Historique")),
          ),
          body: Center(
            child: Text(
              '${AppLocalizations.globalText("Factures du client ID")} $clientId',
            ),
          ),
        ),
      ),
    );
  }

  void startOrder(int clientId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${AppLocalizations.globalText("Commande pour client ID")} $clientId',
        ),
      ),
    );
  }

  void logout() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.globalText("Clients")),
        actions: [IconButton(onPressed: logout, icon: Icon(Icons.logout))],
      ),

      body: Column(
        children: [
          // FORM
          Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                TextField(
                  controller: nomController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.globalText("Nom"),
                  ),
                ),
                TextField(
                  controller: prenomController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.globalText("Prénom"),
                  ),
                ),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.globalText("Email"),
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: addClient,
                  child: Text(AppLocalizations.globalText("Ajouter client")),
                ),
              ],
            ),
          ),

          Divider(),

          Expanded(
            child: ListView.builder(
              itemCount: clients.length,
              itemBuilder: (context, index) {
                final c = clients[index];

                return Card(
                  child: ListTile(
                    leading: Icon(Icons.person),

                    title: Text("${c['nom_client']} ${c['prenom_client']}"),
                    subtitle: Text(c['email']),

                    onTap: () => startOrder(c['id']),

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.history),
                          onPressed: () => openHistory(c['id']),
                        ),

                        Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
