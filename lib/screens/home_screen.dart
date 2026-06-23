import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

import '../database/database_helper.dart';
import 'clients/clients_screen.dart';
import 'orders/new_order_screen.dart';
import 'orders/order_history_screen.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  List<_ClientRow> _clients = [];
  bool _isLoading = true;

  static const _darkBlue = Color(0xFF041B45);
  static const _deepBlue = Color(0xFF06265B);
  static const _primaryBlue = Color(0xFF1B73F8);
  static const _textDark = Color(0xFF111B3D);
  static const _textMuted = Color(0xFF74809A);

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT
          clients.id,
          clients.nom_client,
          clients.prenom_client,
          clients.email,
          MAX(factures.date) AS last_order
        FROM clients
        LEFT JOIN factures ON factures.id_client = clients.id
        GROUP BY clients.id
        ORDER BY clients.id DESC
      ''');

      if (!mounted) return;

      setState(() {
        _clients = rows.map(_ClientRow.fromDb).toList();
        if (_clients.isEmpty) {
          _clients = _ClientRow.demoRows;
        }
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('HomeScreen: erreur chargement clients: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;

      setState(() {
        _clients = _ClientRow.demoRows;
        _isLoading = false;
      });
    }
  }

  List<_ClientRow> get _filteredClients {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _clients;

    return _clients.where((client) {
      return client.fullName.toLowerCase().contains(query) ||
          client.company.toLowerCase().contains(query) ||
          client.lastOrder.toLowerCase().contains(query);
    }).toList();
  }

  void _logout() {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _openNewOrder(_ClientRow client) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewOrderScreen(
          clientId: client.id,
          clientName: client.fullName,
          clientCompany: client.company,
        ),
      ),
    );
    _loadClients();
  }

  void _openHistory(_ClientRow client) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderHistoryScreen(
          clientId: client.id,
          clientName: client.fullName,
        ),
      ),
    );
  }

  Future<void> _editSelectedClient() async {
    final client = await _chooseClient('Modifier un client');
    if (!mounted) return;
    if (client == null) {
      return;
    }

    final firstNameController = TextEditingController(text: client.firstName);
    final lastNameController = TextEditingController(text: client.lastName);
    final emailController = TextEditingController(text: client.email);

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.globalText('Modifier le client')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(labelText: 'Nom'),
              ),
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(labelText: 'Prénom'),
              ),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.globalText('Annuler')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.globalText('Enregistrer')),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      firstNameController.dispose();
      lastNameController.dispose();
      emailController.dispose();
      return;
    }

    final updated = client.copyWith(
      firstName: firstNameController.text.trim().isEmpty
          ? client.firstName
          : firstNameController.text.trim(),
      lastName: lastNameController.text.trim().isEmpty
          ? client.lastName
          : lastNameController.text.trim(),
      email: emailController.text.trim(),
    );

    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();

    if (client.isFromDatabase) {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'clients',
        {
          'nom_client': updated.lastName,
          'prenom_client': updated.firstName,
          'email': updated.email,
        },
        where: 'id = ?',
        whereArgs: [client.id],
      );
      await _loadClients();
    } else {
      setState(() {
        _clients = _clients
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
      });
    }

    _showQuickAction('Client modifié');
  }

  Future<void> _deleteSelectedClient() async {
    final client = await _chooseClient('Supprimer un client');
    if (!mounted) return;
    if (client == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.globalText('Supprimer le client')),
          content: Text('Supprimer ${client.fullName} ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.globalText('Annuler')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFE83A3A),
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.globalText('Supprimer')),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteClient(client);
    }
  }

  Future<_ClientRow?> _chooseClient(String title) {
    final clients = _filteredClients;
    if (clients.isEmpty) {
      _showQuickAction('Aucun client disponible');
      return Future.value(null);
    }

    return showDialog<_ClientRow>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(title),
          children: clients.map((client) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, client),
              child: Text(client.fullName),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _deleteClient(_ClientRow client) async {
    if (client.id > 0) {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'factures',
        where: 'id_client = ?',
        whereArgs: [client.id],
      );
      await db.delete('clients', where: 'id = ?', whereArgs: [client.id]);
    }

    if (!mounted) return;
    setState(() {
      _clients = _clients.where((item) => item.id != client.id).toList();
    });
    _showQuickAction('${client.fullName} supprimé');
  }

  void _openClients() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClientsScreen()),
    ).then((_) => _loadClients());
  }

  void _showQuickAction(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _textDark,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3F7FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final compact = viewport.maxWidth < 720;
            final shellHeight = viewport.maxHeight - 36;

            Widget shell(Widget child) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFF7FAFF),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF193A70).withValues(alpha: .13),
                      blurRadius: 30,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: child,
                ),
              );
            }

            if (compact) {
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 1180),
                    child: shell(
                      Column(
                        children: [
                          _Sidebar(
                            compact: true,
                            onLogout: _logout,
                            onClients: _openClients,
                          ),
                          _DashboardContent(
                            isLoading: _isLoading,
                            clients: _filteredClients,
                            searchController: _searchController,
                            onNewOrder: _openNewOrder,
                            onHistory: _openHistory,
                            onAddClient: _openClients,
                            onEditClient: _editSelectedClient,
                            onDeleteClient: _deleteSelectedClient,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 1180),
                  child: SizedBox(
                    height: shellHeight,
                    child: shell(
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 238,
                            child: _Sidebar(
                              compact: false,
                              onLogout: _logout,
                              onClients: _openClients,
                            ),
                          ),
                          Expanded(
                            child: _DashboardContent(
                              isLoading: _isLoading,
                              clients: _filteredClients,
                              searchController: _searchController,
                              onNewOrder: _openNewOrder,
                              onHistory: _openHistory,
                              onAddClient: _openClients,
                              onEditClient: _editSelectedClient,
                              onDeleteClient: _deleteSelectedClient,
                              compact: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  _Sidebar({
    required this.compact,
    required this.onLogout,
    required this.onClients,
  });

  final bool compact;
  final VoidCallback onLogout;
  final VoidCallback onClients;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? null : double.infinity,
      padding: EdgeInsets.fromLTRB(18, compact ? 18 : 28, 18, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_HomeScreenState._deepBlue, _HomeScreenState._darkBlue],
        ),
      ),
      child: compact
          ? Row(
              children: [
                _LogoutButton(onLogout: onLogout),
                Spacer(),
                Text(
                  AppLocalizations.globalText('PréVente'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LogoutButton(onLogout: onLogout),
                SizedBox(height: 64),
                SizedBox(height: 150, child: _MiniCartLogo()),
                Center(
                  child: Text(
                    AppLocalizations.globalText('PréVente'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(height: 52),
                _NavItem(
                  icon: Icons.group_outlined,
                  label: AppLocalizations.globalText('Clients'),
                  selected: true,
                  onTap: onClients,
                ),
                SizedBox(height: 14),
                _NavItem(
                  icon: Icons.shopping_bag_outlined,
                  label: AppLocalizations.globalText('Commandes'),
                  selected: false,
                ),
                SizedBox(height: 14),
                _NavItem(
                  icon: Icons.person_outline,
                  label: AppLocalizations.globalText('Profil'),
                  selected: false,
                ),
              ],
            ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  _LogoutButton({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onLogout,
      icon: Icon(Icons.logout, size: 20),
      label: Text(AppLocalizations.globalText('Déconnexion')),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(
          color: Colors.white.withValues(alpha: .72),
          width: 1.4,
        ),
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: .14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: .86), size: 22),
            SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: selected ? 1 : .72),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  _DashboardContent({
    required this.isLoading,
    required this.clients,
    required this.searchController,
    required this.onNewOrder,
    required this.onHistory,
    required this.onAddClient,
    required this.onEditClient,
    required this.onDeleteClient,
    required this.compact,
  });

  final bool isLoading;
  final List<_ClientRow> clients;
  final TextEditingController searchController;
  final ValueChanged<_ClientRow> onNewOrder;
  final ValueChanged<_ClientRow> onHistory;
  final VoidCallback onAddClient;
  final VoidCallback onEditClient;
  final VoidCallback onDeleteClient;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final table = _ClientsPanel(
      isLoading: isLoading,
      clients: clients,
      searchController: searchController,
      onNewOrder: onNewOrder,
      onHistory: onHistory,
      compact: compact,
    );
    final actions = _QuickActionsPanel(
      onAddClient: onAddClient,
      onEditClient: onEditClient,
      onDeleteClient: onDeleteClient,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 20 : 28,
        compact ? 24 : 34,
        compact ? 20 : 28,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.globalText('Home'),
            style: TextStyle(
              color: _HomeScreenState._textDark,
              fontSize: 30,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 50),
          Text(
            AppLocalizations.globalText(
              'Gestion des Préventes - Tableau de bord',
            ),
            style: TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 58),
          compact
              ? Column(children: [table, SizedBox(height: 20), actions])
              : Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: table),
                      SizedBox(width: 24),
                      Expanded(flex: 3, child: actions),
                    ],
                  ),
                ),
          SizedBox(height: 16),
          Text(
            AppLocalizations.globalText('© 2024 PréVente.'),
            style: TextStyle(
              color: _HomeScreenState._textDark,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientsPanel extends StatelessWidget {
  _ClientsPanel({
    required this.isLoading,
    required this.clients,
    required this.searchController,
    required this.onNewOrder,
    required this.onHistory,
    required this.compact,
  });

  final bool isLoading;
  final List<_ClientRow> clients;
  final TextEditingController searchController;
  final ValueChanged<_ClientRow> onNewOrder;
  final ValueChanged<_ClientRow> onHistory;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF193A70).withValues(alpha: .08),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.globalText('Vos Clients'),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.globalText(
                        'Rechercher clients',
                      ),
                      hintStyle: TextStyle(
                        color: Color(0xFF9AA4B7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide(color: Color(0xFFD8DEE9)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide(color: Color(0xFFD8DEE9)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Color(0xFFE6EAF2)),
          if (compact)
            _CompactClientsList(
              isLoading: isLoading,
              clients: clients,
              onNewOrder: onNewOrder,
              onHistory: onHistory,
            )
          else
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 440) {
                          return _ScrollableMobileClients(
                            clients: clients,
                            onNewOrder: onNewOrder,
                            onHistory: onHistory,
                          );
                        }

                        return Column(
                          children: [
                            _TableHeader(),
                            Expanded(
                              child: ListView(
                                padding: EdgeInsets.zero,
                                children: clients
                                    .map(
                                      (client) => _ClientTableRow(
                                        client: client,
                                        onNewOrder: () => onNewOrder(client),
                                        onHistory: () => onHistory(client),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}

class _CompactClientsList extends StatelessWidget {
  _CompactClientsList({
    required this.isLoading,
    required this.clients,
    required this.onNewOrder,
    required this.onHistory,
  });

  final bool isLoading;
  final List<_ClientRow> clients;
  final ValueChanged<_ClientRow> onNewOrder;
  final ValueChanged<_ClientRow> onHistory;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: EdgeInsets.all(48),
        child: CircularProgressIndicator(),
      );
    }

    return _ScrollableMobileClients(
      clients: clients,
      onNewOrder: onNewOrder,
      onHistory: onHistory,
      shrinkWrap: true,
    );
  }
}

class _ScrollableMobileClients extends StatelessWidget {
  _ScrollableMobileClients({
    required this.clients,
    required this.onNewOrder,
    required this.onHistory,
    this.shrinkWrap = false,
  });

  final List<_ClientRow> clients;
  final ValueChanged<_ClientRow> onNewOrder;
  final ValueChanged<_ClientRow> onHistory;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? NeverScrollableScrollPhysics() : null,
      itemCount: clients.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: Color(0xFFE6EAF2)),
      itemBuilder: (context, index) {
        final client = clients[index];
        return _MobileClientTile(
          client: client,
          onNewOrder: () => onNewOrder(client),
          onHistory: () => onHistory(client),
        );
      },
    );
  }
}

class _TableHeader extends StatelessWidget {
  _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF4F6FA),
      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 15),
      child: Row(
        children: [
          Expanded(flex: 32, child: _HeaderText('Client')),
          Expanded(flex: 20, child: _HeaderText('Entreprise')),
          Expanded(flex: 25, child: _HeaderText('Dernière\nCommande')),
          Expanded(flex: 30, child: _HeaderText('Actions')),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.black,
        fontSize: 13,
        height: 1.15,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _ClientTableRow extends StatelessWidget {
  _ClientTableRow({
    required this.client,
    required this.onNewOrder,
    required this.onHistory,
  });

  final _ClientRow client;
  final VoidCallback onNewOrder;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE6EAF2))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 32,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: client.avatarColor.withValues(alpha: .18),
                  child: Text(
                    client.initials,
                    style: TextStyle(
                      color: client.avatarColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    client.twoLineName,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 20,
            child: Text(
              client.company,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 24,
            child: Text(
              client.lastOrder,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 30,
            child: _ClientActionButtons(
              onNewOrder: onNewOrder,
              onHistory: onHistory,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileClientTile extends StatelessWidget {
  _MobileClientTile({
    required this.client,
    required this.onNewOrder,
    required this.onHistory,
  });

  final _ClientRow client;
  final VoidCallback onNewOrder;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: client.avatarColor.withValues(alpha: .18),
                child: Text(client.initials),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _HomeScreenState._textDark,
                      ),
                    ),
                    Text(
                      '${client.company} - ${client.lastOrder}',
                      style: TextStyle(
                        color: _HomeScreenState._textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _ClientActionButtons(onNewOrder: onNewOrder, onHistory: onHistory),
        ],
      ),
    );
  }
}

class _ClientActionButtons extends StatelessWidget {
  _ClientActionButtons({required this.onNewOrder, required this.onHistory});

  final VoidCallback onNewOrder;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SmallActionButton(
          label: AppLocalizations.globalText('Nouvelle Commande'),
          icon: Icons.add_shopping_cart,
          color: Color(0xFFEBF7FF),
          borderColor: Color(0xFF94C7EA),
          textColor: Color(0xFF164260),
          onPressed: onNewOrder,
        ),
        SizedBox(height: 5),
        _SmallActionButton(
          label: AppLocalizations.globalText('Historique'),
          icon: Icons.history,
          color: Color(0xFFFFF4F1),
          borderColor: Color(0xFFEAB1A8),
          textColor: Color(0xFF5B3A34),
          onPressed: onHistory,
        ),
      ],
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  _SmallActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.borderColor,
    required this.textColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 21,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 12),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          side: BorderSide(color: borderColor),
          padding: EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  _QuickActionsPanel({
    required this.onAddClient,
    required this.onEditClient,
    required this.onDeleteClient,
  });

  final VoidCallback onAddClient;
  final VoidCallback onEditClient;
  final VoidCallback onDeleteClient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF193A70).withValues(alpha: .08),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.globalText('Action Rapide'),
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 18),
          Text(
            AppLocalizations.globalText('Gestion Client'),
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 14),
          _QuickButton(
            icon: Icons.person_add_alt_1,
            label: AppLocalizations.globalText('Ajouter un\nNouveau Client'),
            color: _HomeScreenState._primaryBlue,
            onPressed: onAddClient,
          ),
          SizedBox(height: 10),
          _QuickButton(
            icon: Icons.edit_outlined,
            label: AppLocalizations.globalText('Modifier un\nClient Existant'),
            color: Color(0xFF1E8CEB),
            onPressed: onEditClient,
          ),
          SizedBox(height: 10),
          _QuickButton(
            icon: Icons.delete_outline,
            label: AppLocalizations.globalText('Supprimer un\nClient Existant'),
            color: Color(0xFFE83A3A),
            onPressed: onDeleteClient,
          ),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  _QuickButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label, textAlign: TextAlign.center),
        style: ElevatedButton.styleFrom(
          elevation: 2,
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          textStyle: TextStyle(
            fontSize: 11,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MiniCartLogo extends StatelessWidget {
  _MiniCartLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MiniCartPainter());
  }
}

class _MiniCartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final w = size.width;
    final h = size.height;

    paint.color = const Color(0xFF0D3A84).withValues(alpha: .72);
    canvas.drawCircle(Offset(w * .50, h * .50), w * .28, paint);
    canvas.drawCircle(Offset(w * .68, h * .58), w * .16, paint);

    paint.color = const Color(0xFFFF3F6A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .33, h * .38, w * .12, h * .18),
        Radius.circular(4),
      ),
      paint,
    );
    paint.color = const Color(0xFF1DD3D3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .48, h * .31, w * .13, h * .22),
        Radius.circular(4),
      ),
      paint,
    );
    paint.color = const Color(0xFFFFB23C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .58, h * .42, w * .14, h * .20),
        Radius.circular(4),
      ),
      paint,
    );

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF8ED5FF);
    final basket = Path()
      ..moveTo(w * .24, h * .48)
      ..lineTo(w * .75, h * .48)
      ..lineTo(w * .68, h * .72)
      ..lineTo(w * .32, h * .72)
      ..close();
    canvas.drawPath(basket, paint);
    canvas.drawLine(Offset(w * .28, h * .78), Offset(w * .68, h * .78), paint);

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFD6F1FF);
    canvas.drawCircle(Offset(w * .35, h * .85), 5, paint);
    canvas.drawCircle(Offset(w * .64, h * .85), 5, paint);

    paint.color = const Color(0xFF20D6C7);
    canvas.drawCircle(Offset(w * .76, h * .58), 16, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white;
    canvas.drawLine(Offset(w * .73, h * .58), Offset(w * .76, h * .62), paint);
    canvas.drawLine(Offset(w * .76, h * .62), Offset(w * .81, h * .54), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ClientRow {
  _ClientRow({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.company,
    required this.lastOrder,
    required this.avatarColor,
    this.email = '',
    this.isFromDatabase = false,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String company;
  final String lastOrder;
  final Color avatarColor;
  final String email;
  final bool isFromDatabase;

  String get fullName => '$firstName $lastName'.trim();
  String get twoLineName => '$firstName\n$lastName';
  String get initials {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    return '$first$last'.toUpperCase();
  }

  factory _ClientRow.fromDb(Map<String, Object?> row) {
    final firstName = (row['prenom_client'] ?? '').toString().trim();
    final lastName = (row['nom_client'] ?? '').toString().trim();
    final email = (row['email'] ?? '').toString();
    final id = (row['id'] as int?) ?? 0;

    return _ClientRow(
      id: id,
      firstName: firstName.isEmpty ? 'Client' : firstName,
      lastName: lastName.isEmpty ? '#$id' : lastName,
      company: _companyFromEmail(email),
      lastOrder: _formatDate((row['last_order'] ?? '').toString()),
      avatarColor: _avatarColors[id % _avatarColors.length],
      email: email,
      isFromDatabase: true,
    );
  }

  _ClientRow copyWith({String? firstName, String? lastName, String? email}) {
    final updatedEmail = email ?? this.email;
    return _ClientRow(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      company: updatedEmail.isEmpty ? company : _companyFromEmail(updatedEmail),
      lastOrder: lastOrder,
      avatarColor: avatarColor,
      email: updatedEmail,
      isFromDatabase: isFromDatabase,
    );
  }

  static String _companyFromEmail(String email) {
    if (!email.contains('@')) return 'Entreprise';
    final domain = email.split('@').last.split('.').first;
    if (domain.isEmpty) return 'Entreprise';
    return domain[0].toUpperCase() + domain.substring(1);
  }

  static String _formatDate(String value) {
    if (value.isEmpty) return '01/01/2024';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static final _avatarColors = [
    Color(0xFF9B6B4F),
    Color(0xFF2B8C88),
    Color(0xFFB35C7C),
    Color(0xFF526CC9),
    Color(0xFFB98A2E),
  ];

  static final demoRows = [
    _ClientRow(
      id: 1,
      firstName: 'Avatar',
      lastName: 'Antari',
      company: 'Entreprise',
      lastOrder: '01/01/2024',
      avatarColor: Color(0xFF9B6B4F),
    ),
    _ClientRow(
      id: 2,
      firstName: 'Mars',
      lastName: 'Brochen',
      company: 'Entreprise',
      lastOrder: '23/01/2024',
      avatarColor: Color(0xFF2B8C88),
    ),
    _ClientRow(
      id: 3,
      firstName: 'Emme',
      lastName: 'Brosetez',
      company: 'Entreprise',
      lastOrder: '29/01/2024',
      avatarColor: Color(0xFFB35C7C),
    ),
    _ClientRow(
      id: 4,
      firstName: 'Mafe',
      lastName: 'Bronard',
      company: 'Entreprise',
      lastOrder: '31/01/2024',
      avatarColor: Color(0xFF526CC9),
    ),
    _ClientRow(
      id: 5,
      firstName: 'Austan',
      lastName: 'Baravil',
      company: 'RWG',
      lastOrder: '07/01/2024',
      avatarColor: Color(0xFFB98A2E),
    ),
    _ClientRow(
      id: 6,
      firstName: 'Maria',
      lastName: 'Donnas',
      company: 'RWG',
      lastOrder: '07/01/2024',
      avatarColor: Color(0xFF9B6B4F),
    ),
    _ClientRow(
      id: 7,
      firstName: 'Jomm',
      lastName: 'Brochez',
      company: 'Entreprise',
      lastOrder: '07/01/2024',
      avatarColor: Color(0xFF2B8C88),
    ),
    _ClientRow(
      id: 8,
      firstName: 'Dannes',
      lastName: 'Darass',
      company: 'RWG',
      lastOrder: '19/01/2024',
      avatarColor: Color(0xFFB35C7C),
    ),
    _ClientRow(
      id: 9,
      firstName: 'Belge',
      lastName: 'Alexandez',
      company: 'Ressfian\nCetreprise',
      lastOrder: '27/01/2024',
      avatarColor: Color(0xFF526CC9),
    ),
    _ClientRow(
      id: 10,
      firstName: 'Irek',
      lastName: 'Omoner',
      company: 'Mazves',
      lastOrder: '26/07/2024',
      avatarColor: Color(0xFFB98A2E),
    ),
    _ClientRow(
      id: 11,
      firstName: 'Maria',
      lastName: 'Bnarein',
      company: 'RWG',
      lastOrder: '15/08/2024',
      avatarColor: Color(0xFF9B6B4F),
    ),
    _ClientRow(
      id: 12,
      firstName: 'Frav',
      lastName: 'Andreas',
      company: 'RWG',
      lastOrder: '19/05/2024',
      avatarColor: Color(0xFF2B8C88),
    ),
  ];
}
