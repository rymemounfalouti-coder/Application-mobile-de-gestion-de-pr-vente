import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';
import 'order_cart.dart';

final _darkBlue = Color(0xFF041B45);
final _deepBlue = Color(0xFF06265B);
final _textDark = Color(0xFF111B3D);

class ProductsByCategoryScreen extends StatefulWidget {
  ProductsByCategoryScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.categoryId,
    required this.categoryName,
    required this.cart,
  });

  final int clientId;
  final String clientName;
  final int categoryId;
  final String categoryName;
  final Map<int, OrderCartItem> cart;

  @override
  State<ProductsByCategoryScreen> createState() =>
      _ProductsByCategoryScreenState();
}

class _ProductsByCategoryScreenState extends State<ProductsByCategoryScreen> {
  List<_ProductItem> _products = [];
  bool _isSaving = false;
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final db = await DatabaseHelper.instance.database;
    await _seedProductsIfNeeded(db);

    final rows = await db.query(
      'produits',
      where: 'id_cat = ?',
      whereArgs: [widget.categoryId],
      orderBy: 'id ASC',
    );

    if (!mounted) return;

    setState(() {
      _products = rows.map(_ProductItem.fromDb).toList();
      _isLoadingProducts = false;
    });
  }

  int get _cartCount =>
      widget.cart.values.fold(0, (total, item) => total + item.quantity);

  double get _cartTotal =>
      widget.cart.values.fold(0, (total, item) => total + item.total);

  List<OrderCartItem> get _cartLines => widget.cart.values.toList();

  void _increment(_ProductItem product) {
    final current = widget.cart[product.id];
    setState(() {
      widget.cart[product.id] = current == null
          ? OrderCartItem(
              productId: product.id,
              name: product.name,
              shortName: product.shortName,
              unitPrice: product.price,
              quantity: 1,
            )
          : current.copyWith(quantity: current.quantity + 1);
    });
  }

  void _decrement(_ProductItem product) {
    final current = widget.cart[product.id];
    if (current == null) return;

    setState(() {
      if (current.quantity <= 1) {
        widget.cart.remove(product.id);
      } else {
        widget.cart[product.id] = current.copyWith(
          quantity: current.quantity - 1,
        );
      }
    });
  }

  Future<void> _addOrder() async {
    if (_cartCount == 0) {
      _showMessage('Veuillez sélectionner au moins un produit');
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.clientId > 0) {
        final db = await DatabaseHelper.instance.database;
        final factureId = await db.insert('factures', {
          'id_client': widget.clientId,
          'date': DateTime.now().toIso8601String(),
          'total': _cartTotal,
        });

        for (final line in _cartLines) {
          await db.insert('details_facture', {
            'id_fact': factureId,
            'id_prod': line.productId,
            'qte': line.quantity,
            'prix_vendu': line.unitPrice,
          });
        }
      }

      if (!mounted) return;
      _showMessage('Commande ajouté avec succès');
      setState(widget.cart.clear);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
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
            final shellHeight = (viewport.maxHeight - 36)
                .clamp(620.0, 860.0)
                .toDouble();

            return Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 1180),
                  child: DecoratedBox(
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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 760;
                          final content = _ProductsContent(
                            categoryName: widget.categoryName,
                            products: _products,
                            cart: widget.cart,
                            cartCount: _cartCount,
                            cartTotal: _cartTotal,
                            cartLines: _cartLines,
                            isSaving: _isSaving,
                            isLoadingProducts: _isLoadingProducts,
                            onBack: () => Navigator.pop(context),
                            onIncrement: _increment,
                            onDecrement: _decrement,
                            onAddOrder: _addOrder,
                            compact: compact,
                          );

                          if (compact) {
                            return SizedBox(
                              height: shellHeight,
                              child: Column(
                                children: [
                                  _ProductsSidebar(
                                    compact: true,
                                    onLogout: () =>
                                        Navigator.pushNamedAndRemoveUntil(
                                          context,
                                          '/login',
                                          (route) => false,
                                        ),
                                  ),
                                  Expanded(child: content),
                                ],
                              ),
                            );
                          }

                          return SizedBox(
                            height: shellHeight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: 220,
                                  child: _ProductsSidebar(
                                    compact: false,
                                    onLogout: () =>
                                        Navigator.pushNamedAndRemoveUntil(
                                          context,
                                          '/login',
                                          (route) => false,
                                        ),
                                  ),
                                ),
                                Expanded(child: content),
                              ],
                            ),
                          );
                        },
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

class _ProductsSidebar extends StatelessWidget {
  _ProductsSidebar({required this.compact, required this.onLogout});

  final bool compact;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? null : double.infinity,
      padding: EdgeInsets.fromLTRB(18, compact ? 18 : 24, 18, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_deepBlue, _darkBlue],
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
                SizedBox(height: 56),
                SizedBox(height: 130, child: _MiniCartLogo()),
                Center(
                  child: Text(
                    AppLocalizations.globalText('PréVente'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(height: 52),
                _ProductsNavItem(
                  icon: Icons.home_outlined,
                  label: AppLocalizations.globalText('Tableau de bord'),
                ),
                SizedBox(height: 18),
                _ProductsNavItem(
                  icon: Icons.group_outlined,
                  label: AppLocalizations.globalText('Clients'),
                ),
                SizedBox(height: 18),
                _ProductsNavItem(
                  icon: Icons.shopping_bag_outlined,
                  label: AppLocalizations.globalText('Commandes'),
                ),
                SizedBox(height: 18),
                _ProductsNavItem(
                  icon: Icons.sell_outlined,
                  label: AppLocalizations.globalText('Produits'),
                ),
                SizedBox(height: 18),
                _ProductsNavItem(
                  icon: Icons.person_outline,
                  label: AppLocalizations.globalText('Profil'),
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
      icon: Icon(Icons.logout, size: 18),
      label: Text(AppLocalizations.globalText('Déconnexion')),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(
          color: Colors.white.withValues(alpha: .72),
          width: 1.3,
        ),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ProductsNavItem extends StatelessWidget {
  _ProductsNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: .72), size: 21),
        SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .70),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProductsContent extends StatelessWidget {
  _ProductsContent({
    required this.categoryName,
    required this.products,
    required this.cart,
    required this.cartCount,
    required this.cartTotal,
    required this.cartLines,
    required this.isSaving,
    required this.isLoadingProducts,
    required this.onBack,
    required this.onIncrement,
    required this.onDecrement,
    required this.onAddOrder,
    required this.compact,
  });

  final String categoryName;
  final List<_ProductItem> products;
  final Map<int, OrderCartItem> cart;
  final int cartCount;
  final double cartTotal;
  final List<OrderCartItem> cartLines;
  final bool isSaving;
  final bool isLoadingProducts;
  final VoidCallback onBack;
  final ValueChanged<_ProductItem> onIncrement;
  final ValueChanged<_ProductItem> onDecrement;
  final VoidCallback onAddOrder;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(top: 20, right: 30, child: _DotPattern()),
        Padding(
          padding: EdgeInsets.fromLTRB(compact ? 20 : 24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.globalText('Nouvelle Commande'),
                style: TextStyle(
                  color: Colors.black,
                  fontSize: compact ? 25 : 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 28),
              TextButton.icon(
                onPressed: onBack,
                icon: Icon(Icons.arrow_back, size: 18),
                label: Text(
                  AppLocalizations.globalText('Retour aux catégories'),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Color(0xFFDDF1FF),
                  foregroundColor: Color(0xFF164260),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
              SizedBox(height: 32),
              SizedBox(width: 430, child: Divider(color: Color(0xFFDDE3EE))),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.only(left: 14),
                child: Text(
                  'Liste des $categoryName',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Expanded(
                child: compact
                    ? Column(
                        children: [
                          Expanded(
                            child: _ProductsGrid(
                              products: products,
                              cart: cart,
                              isLoading: isLoadingProducts,
                              onIncrement: onIncrement,
                              onDecrement: onDecrement,
                              compact: true,
                            ),
                          ),
                          SizedBox(height: 16),
                          _CartPanel(
                            cartLines: cartLines,
                            total: cartTotal,
                            isSaving: isSaving,
                            onAddOrder: onAddOrder,
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 430,
                            child: _ProductsGrid(
                              products: products,
                              cart: cart,
                              isLoading: isLoadingProducts,
                              onIncrement: onIncrement,
                              onDecrement: onDecrement,
                              compact: false,
                            ),
                          ),
                          SizedBox(width: 24),
                          SizedBox(
                            width: 210,
                            child: _CartPanel(
                              cartLines: cartLines,
                              total: cartTotal,
                              isSaving: isSaving,
                              onAddOrder: onAddOrder,
                            ),
                          ),
                          Spacer(),
                          _FloatingCartBadge(count: cartCount),
                        ],
                      ),
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.globalText('© 2024 PréVente.'),
                style: TextStyle(
                  color: _textDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductsGrid extends StatelessWidget {
  _ProductsGrid({
    required this.products,
    required this.cart,
    required this.isLoading,
    required this.onIncrement,
    required this.onDecrement,
    required this.compact,
  });

  final List<_ProductItem> products;
  final Map<int, OrderCartItem> cart;
  final bool isLoading;
  final ValueChanged<_ProductItem> onIncrement;
  final ValueChanged<_ProductItem> onDecrement;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: Color(0xFF2F8FE8)));
    }

    if (products.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.globalText('Aucun produit dans cette catégorie'),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.only(bottom: 12),
      itemCount: products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: compact ? 1 : 2,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: compact ? 1.35 : .78,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductCard(
          product: product,
          quantity: cart[product.id]?.quantity ?? 0,
          onIncrement: () => onIncrement(product),
          onDecrement: () => onDecrement(product),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  _ProductCard({
    required this.product,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final _ProductItem product;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF193A70).withValues(alpha: .08),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text(product.icon, style: TextStyle(fontSize: 58))),
          Spacer(),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16, height: 1.1),
          ),
          SizedBox(height: 4),
          Text('${product.price.toStringAsFixed(2)} DH'),
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _QuantityButton(icon: Icons.remove, onPressed: onDecrement),
              Text('$quantity', style: TextStyle(fontSize: 24)),
              _QuantityButton(icon: Icons.add, onPressed: onIncrement),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  _QuantityButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: _darkBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Icon(icon, size: 28),
      ),
    );
  }
}

class _CartPanel extends StatelessWidget {
  _CartPanel({
    required this.cartLines,
    required this.total,
    required this.isSaving,
    required this.onAddOrder,
  });

  final List<OrderCartItem> cartLines;
  final double total;
  final bool isSaving;
  final VoidCallback onAddOrder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF193A70).withValues(alpha: .08),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              AppLocalizations.globalText('Mon Panier de\nCommande'),
              style: TextStyle(fontSize: 18),
            ),
          ),
          Container(
            color: Color(0xFFF3F6FB),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(AppLocalizations.globalText('Article')),
                ),
                Expanded(
                  flex: 2,
                  child: Text(AppLocalizations.globalText('Qté')),
                ),
                Expanded(
                  flex: 3,
                  child: Text(AppLocalizations.globalText('Prix\nTotal')),
                ),
              ],
            ),
          ),
          if (cartLines.isEmpty)
            Padding(
              padding: EdgeInsets.all(14),
              child: Text(AppLocalizations.globalText('Aucun article')),
            )
          else
            ...cartLines.map(
              (line) => Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        line.shortName,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${line.quantity}',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${line.total.toStringAsFixed(2)} DH',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('Total TTC: ${total.toStringAsFixed(2)} DH'),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 14),
            child: SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: isSaving ? null : onAddOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2F8FE8),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(isSaving ? 'Ajout...' : 'Ajouter la commande'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingCartBadge extends StatelessWidget {
  _FloatingCartBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 390, right: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Color(0xFF2F8FE8),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_cart_outlined, color: Colors.white),
          ),
          Positioned(
            top: -4,
            right: -2,
            child: CircleAvatar(
              radius: 11,
              backgroundColor: Color(0xFF5AA7F0),
              child: Text(
                '$count',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotPattern extends StatelessWidget {
  _DotPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(150, 100), painter: _DotPatternPainter());
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB7C7DE).withValues(alpha: .35)
      ..isAntiAlias = true;

    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 12; col++) {
        canvas.drawCircle(Offset(col * 12.0, row * 12.0), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

class _ProductItem {
  _ProductItem({
    required this.id,
    required this.name,
    required this.shortName,
    required this.price,
    required this.icon,
  });

  final int id;
  final String name;
  final String shortName;
  final double price;
  final String icon;

  factory _ProductItem.fromDb(Map<String, Object?> row) {
    final name = (row['nom_produit'] ?? 'Produit').toString();
    return _ProductItem(
      id: (row['id'] as int?) ?? 0,
      name: name,
      shortName: _shortName(name),
      price: ((row['prix'] as num?) ?? 0).toDouble(),
      icon: _iconForName(name),
    );
  }

  // ignore: unused_element
  static List<_ProductItem> forCategory(String categoryName) {
    return [
      _ProductItem(
        id: 1,
        name: 'Coca-Cola Classic (33cl)',
        shortName: 'Coca-Cola\n(33cl)',
        price: 15.00,
        icon: 'ðŸ¥¤',
      ),
      _ProductItem(
        id: 2,
        name: 'Fanta Orange (33cl)',
        shortName: 'Fanta\n(33cl)',
        price: 14.50,
        icon: 'ðŸ§ƒ',
      ),
      _ProductItem(
        id: 3,
        name: 'Sprite (33cl)',
        shortName: 'Sprite\n(33cl)',
        price: 14.50,
        icon: 'ðŸ¥¤',
      ),
      _ProductItem(
        id: 4,
        name: 'Evian Eau Minérale (50cl)',
        shortName: 'Evian\n(50cl)',
        price: 11.00,
        icon: 'ðŸ’§',
      ),
      _ProductItem(
        id: 5,
        name: 'Perrier Eau Gazeuse (33cl)',
        shortName: 'Perrier\n(33cl)',
        price: 12.50,
        icon: 'ðŸ¾',
      ),
      _ProductItem(
        id: 6,
        name: "Jus d'Orange Bio (1L)",
        shortName: "Jus d'Orange\n(1L)",
        price: 32.00,
        icon: 'ðŸ§ƒ',
      ),
      _ProductItem(
        id: 7,
        name: 'Oasis Tropical (33cl)',
        shortName: 'Oasis\n(33cl)',
        price: 13.50,
        icon: 'ðŸ§ƒ',
      ),
      _ProductItem(
        id: 8,
        name: 'Ice Tea Pêche (33cl)',
        shortName: 'Ice Tea\n(33cl)',
        price: 16.00,
        icon: 'ðŸ¥¤',
      ),
      _ProductItem(
        id: 9,
        name: 'Eau Minérale (1.5L)',
        shortName: 'Eau\n(1.5L)',
        price: 10.00,
        icon: 'ðŸ’§',
      ),
      _ProductItem(
        id: 10,
        name: 'Red Bull (25cl)',
        shortName: 'Red Bull\n(25cl)',
        price: 28.00,
        icon: 'ðŸ¥«',
      ),
    ];
  }
}

String _shortName(String name) {
  final parts = name.split(' ');
  if (parts.length <= 2) return name;
  return '${parts.take(2).join(' ')}\n${parts.skip(2).join(' ')}';
}

String _iconForName(String name) {
  final value = name.toLowerCase();
  if (value.contains('eau') || value.contains('perrier')) return 'ðŸ’§';
  if (value.contains('coca') ||
      value.contains('fanta') ||
      value.contains('sprite') ||
      value.contains('jus') ||
      value.contains('tea') ||
      value.contains('oasis') ||
      value.contains('soda')) {
    return 'ðŸ¥¤';
  }
  if (value.contains('pain') ||
      value.contains('baguette') ||
      value.contains('croissant')) {
    return 'ðŸ¥–';
  }
  if (value.contains('lait') ||
      value.contains('yaourt') ||
      value.contains('fromage')) {
    return 'ðŸ§€';
  }
  if (value.contains('poulet') ||
      value.contains('boeuf') ||
      value.contains('poisson')) {
    return 'ðŸ—';
  }
  if (value.contains('pomme') ||
      value.contains('banane') ||
      value.contains('tomate')) {
    return 'ðŸŽ';
  }
  if (value.contains('biscuit') ||
      value.contains('chocolat') ||
      value.contains('gateau')) {
    return 'ðŸª';
  }
  if (value.contains('chips') || value.contains('olive')) return 'ðŸ¥«';
  if (value.contains('savon') || value.contains('shampoing')) return 'ðŸ§´';
  if (value.contains('glace') || value.contains('surg')) return 'ðŸ§Š';
  return 'ðŸ›’';
}

Future<void> _seedProductsIfNeeded(Database db) async {
  final countRows = await db.rawQuery('SELECT COUNT(*) AS count FROM produits');
  final productCount = (countRows.first['count'] as int?) ?? 0;
  if (productCount > 0) return;

  final categoryCountRows = await db.rawQuery(
    'SELECT COUNT(*) AS count FROM categories',
  );
  final categoryCount = (categoryCountRows.first['count'] as int?) ?? 0;
  if (categoryCount == 0) {
    for (final category in _seedCategoryNames) {
      await db.insert('categories', {'nom_cat': category});
    }
  }

  final batch = db.batch();
  _seedProductsByCategory.forEach((categoryId, products) {
    for (final product in products) {
      batch.insert('produits', {
        'id_cat': categoryId,
        'nom_produit': product.$1,
        'prix': product.$2,
      });
    }
  });
  await batch.commit(noResult: true);
}

final _seedCategoryNames = [
  'Boissons & Sodas',
  'Boulangerie',
  'Produits Laitiers',
  'Viandes & Poissons',
  'Fruits & Legumes',
  'Epicerie Sucree',
  'Epicerie Salee',
  'Hygiene',
  'Surgeles',
];

Map<int, List<(String, double)>> _seedProductsByCategory = {
  1: [
    ('Coca-Cola Classic (33cl)', 15.00),
    ('Fanta Orange (33cl)', 14.50),
    ('Sprite (33cl)', 14.50),
    ('Evian Eau Minerale (50cl)', 11.00),
    ('Perrier Eau Gazeuse (33cl)', 12.50),
    ("Jus d'Orange Bio (1L)", 32.00),
    ('Oasis Tropical (33cl)', 13.50),
    ('Ice Tea Peche (33cl)', 16.00),
    ('Eau Minerale (1.5L)', 10.00),
    ('Red Bull (25cl)', 28.00),
  ],
  2: [
    ('Baguette Tradition', 3.50),
    ('Pain Complet', 8.00),
    ('Croissant Beurre', 4.00),
    ('Pain Chocolat', 4.50),
    ('Brioche Nature', 12.00),
    ('Pain Burger', 10.00),
    ('Pain Toast', 14.00),
    ('Muffin Vanille', 7.50),
    ('Madeleine Sachet', 9.00),
    ('Cake Marbre', 18.00),
  ],
  3: [
    ('Lait Entier (1L)', 9.50),
    ('Lait Demi-Ecreme (1L)', 9.00),
    ('Yaourt Nature Pack', 18.00),
    ('Yaourt Fraise Pack', 19.00),
    ('Fromage Portions', 16.00),
    ('Beurre Doux', 24.00),
    ('Creme Fraiche', 13.00),
    ('Mozzarella', 22.00),
    ('Fromage Rape', 21.00),
    ('Lben Frais', 8.00),
  ],
  4: [
    ('Poulet Entier', 42.00),
    ('Escalope Poulet', 58.00),
    ('Viande Boeuf Hachee', 75.00),
    ('Steak Boeuf', 88.00),
    ('Poisson Blanc', 65.00),
    ('Thon Frais', 72.00),
    ('Crevettes', 95.00),
    ('Saucisses Poulet', 38.00),
    ('Dinde Fumee', 52.00),
    ('Kefta Assaisonnee', 69.00),
  ],
  5: [
    ('Pommes Rouges', 14.00),
    ('Bananes', 12.00),
    ('Oranges', 10.00),
    ('Tomates', 8.00),
    ('Pommes de Terre', 7.00),
    ('Carottes', 6.50),
    ('Oignons', 6.00),
    ('Salade Verte', 5.00),
    ('Concombres', 7.50),
    ('Citrons', 11.00),
  ],
  6: [
    ('Biscuits Chocolat', 12.00),
    ('Chocolat Noir', 18.00),
    ('Cereales Miel', 24.00),
    ('Confiture Fraise', 21.00),
    ('Miel Naturel', 45.00),
    ('Gateau Fourre', 10.00),
    ('Bonbons Fruits', 9.00),
    ('Pate a Tartiner', 35.00),
    ('Sucre Semoule', 11.00),
    ('Cafe Moulu', 29.00),
  ],
  7: [
    ('Chips Nature', 8.00),
    ('Chips Fromage', 8.50),
    ('Olives Vertes', 18.00),
    ('Thon Conserve', 16.00),
    ('Mais Conserve', 12.00),
    ('Cornichons', 15.00),
    ('Crackers Sales', 11.00),
    ('Sauce Tomate', 9.00),
    ('Pates Spaghetti', 13.00),
    ('Riz Long Grain', 17.00),
  ],
  8: [
    ('Savon Liquide', 22.00),
    ('Shampoing Doux', 34.00),
    ('Gel Douche', 28.00),
    ('Dentifrice', 16.00),
    ('Brosse a Dents', 12.00),
    ('Papier Toilette', 32.00),
    ('Mouchoirs Boite', 10.00),
    ('Deodorant', 25.00),
    ('Lingettes', 18.00),
    ('Creme Mains', 20.00),
  ],
  9: [
    ('Glace Vanille', 26.00),
    ('Glace Chocolat', 26.00),
    ('Legumes Surgeles', 19.00),
    ('Frites Surgeles', 18.00),
    ('Pizza Surgeles', 32.00),
    ('Poisson Pane', 36.00),
    ('Nuggets Poulet', 34.00),
    ('Epinards Surgeles', 16.00),
    ('Petits Pois', 15.00),
    ('Dessert Glace', 29.00),
  ],
};
