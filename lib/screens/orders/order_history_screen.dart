import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../data/mock_presales_data.dart';
import '../../database/database_helper.dart';
import '../invoice/invoice_screen.dart';

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
    try {
      if (widget.clientId <= 0) return _mockOrders();
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'factures',
        where: 'id_client = ?',
        whereArgs: [widget.clientId],
        orderBy: 'date DESC',
      );
      return rows.isEmpty ? _mockOrders() : rows;
    } catch (_) {
      return _mockOrders();
    }
  }

  List<Map<String, dynamic>> _mockOrders() {
    return MockPreSalesData.commercialOrders.values
        .expand((orders) => orders)
        .take(4)
        .map(
          (order) => {
            'id': order.id,
            'id_client': widget.clientId,
            'date': _dateToIso(order.date),
            'total': order.total,
          },
        )
        .toList();
  }

  String _dateToIso(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return value;
    return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
  }

  void _openInvoice(Map<String, dynamic> order) {
    final id = order['id'] is int ? order['id'] as int : 0;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoiceScreen(factureId: id)),
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
      backgroundColor: Color(0xFFF1F8F4),
      appBar: AppBar(
        title: Text(AppLocalizations.globalText('Historique')),
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
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
                        color: Color(0xFF0F172A),
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
                                onTap: () => _openInvoice(order),
                                leading: Icon(Icons.receipt_long),
                                title: Text(
                                  'Commande #${order['id']}',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  _formatDate((order['date'] ?? '').toString()),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${total.toStringAsFixed(2)} DH',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.chevron_right_rounded),
                                  ],
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
