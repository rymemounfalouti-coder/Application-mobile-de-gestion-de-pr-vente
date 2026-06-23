import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../database/database_helper.dart';

class OrderHistoryScreen extends StatefulWidget {
  OrderHistoryScreen({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  final int clientId;
  final String clientName;

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadOrders();
  }

  Future<List<Map<String, dynamic>>> _loadOrders() async {
    if (widget.clientId <= 0) return [];
    final db = await DatabaseHelper.instance.database;
    return db.query(
      'factures',
      where: 'id_client = ?',
      whereArgs: [widget.clientId],
      orderBy: 'date DESC',
    );
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3F7FF),
      appBar: AppBar(
        title: Text(AppLocalizations.globalText('Historique')),
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
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.clientName,
                      style: TextStyle(
                        color: Color(0xFF111B3D),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _ordersFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          final orders = snapshot.data ?? [];
                          if (orders.isEmpty) {
                            return Center(
                              child: Text(
                                AppLocalizations.globalText(
                                  'Aucune commande pour ce client',
                                ),
                                style: TextStyle(color: Color(0xFF74809A)),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: orders.length,
                            separatorBuilder: (context, index) =>
                                Divider(height: 1),
                            itemBuilder: (context, index) {
                              final order = orders[index];
                              final total = ((order['total'] ?? 0) as num)
                                  .toDouble();
                              return ListTile(
                                leading: Icon(Icons.receipt_long),
                                title: Text(
                                  'Commande #${order['id']}',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  _formatDate((order['date'] ?? '').toString()),
                                ),
                                trailing: Text(
                                  '${total.toStringAsFixed(2)} DH',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF111B3D),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
