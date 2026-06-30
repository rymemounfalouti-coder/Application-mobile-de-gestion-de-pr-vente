import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import 'order_cart.dart';
import 'products_by_category_screen.dart' as products_page;

class NewOrderScreen extends StatefulWidget {
  NewOrderScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    this.clientCompany = 'Entreprise',
  });

  final int clientId;
  final String clientName;
  final String clientCompany;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  List<_OrderCategory> _categories = _OrderCategory.defaults;
  final Map<int, OrderCartItem> _cart = {};
  int? _hoveredCategoryId;

  static const _darkBlue = Color(0xFF041B45);
  static const _deepBlue = Color(0xFF06265B);
  static const _textDark = Color(0xFF111B3D);

  @override
  void initState() {
    super.initState();
    _categories = [
      _OrderCategory(
        id: 1,
        title: 'Thé Vert Premium',
        description: 'Gamme premium',
        icon: 'TP',
      ),
      _OrderCategory(
        id: 2,
        title: 'Thé Vert Classique',
        description: 'Gamme classique',
        icon: 'TC',
      ),
    ];
  }

  void _openProducts(_OrderCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => products_page.ProductsByCategoryScreen(
          clientId: widget.clientId,
          clientName: widget.clientName,
          categoryId: category.id,
          categoryName: category.title,
          cart: _cart,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _goBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3F7FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final compact = viewport.maxWidth < 760;
            final shellHeight = viewport.maxHeight - 36;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 1180),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: shellHeight),
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
                        child: compact
                            ? Column(
                                children: [
                                  _OrderSidebar(
                                    compact: true,
                                    onLogout: () =>
                                        Navigator.pushNamedAndRemoveUntil(
                                          context,
                                          '/login',
                                          (route) => false,
                                        ),
                                  ),
                                  _OrderContent(
                                    clientName: widget.clientName,
                                    clientCompany: widget.clientCompany,
                                    categories: _categories,
                                    hoveredCategoryId: _hoveredCategoryId,
                                    onHover: (id) {
                                      setState(() => _hoveredCategoryId = id);
                                    },
                                    onExitHover: () {
                                      setState(() => _hoveredCategoryId = null);
                                    },
                                    onOpenProducts: _openProducts,
                                    onBack: _goBack,
                                    compact: true,
                                  ),
                                ],
                              )
                            : SizedBox(
                                height: shellHeight,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: 220,
                                      child: _OrderSidebar(
                                        compact: false,
                                        onLogout: () =>
                                            Navigator.pushNamedAndRemoveUntil(
                                              context,
                                              '/login',
                                              (route) => false,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _OrderContent(
                                        clientName: widget.clientName,
                                        clientCompany: widget.clientCompany,
                                        categories: _categories,
                                        hoveredCategoryId: _hoveredCategoryId,
                                        onHover: (id) {
                                          setState(
                                            () => _hoveredCategoryId = id,
                                          );
                                        },
                                        onExitHover: () {
                                          setState(
                                            () => _hoveredCategoryId = null,
                                          );
                                        },
                                        onOpenProducts: _openProducts,
                                        onBack: _goBack,
                                        compact: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

class _OrderSidebar extends StatelessWidget {
  _OrderSidebar({required this.compact, required this.onLogout});

  final bool compact;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? null : 860,
      padding: EdgeInsets.fromLTRB(18, compact ? 18 : 24, 18, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _NewOrderScreenState._deepBlue,
            _NewOrderScreenState._darkBlue,
          ],
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
                _OrderNavItem(
                  icon: Icons.home_outlined,
                  label: AppLocalizations.globalText('Tableau de bord'),
                ),
                SizedBox(height: 18),
                _OrderNavItem(
                  icon: Icons.group_outlined,
                  label: AppLocalizations.globalText('Clients'),
                ),
                SizedBox(height: 18),
                _OrderNavItem(
                  icon: Icons.shopping_bag_outlined,
                  label: AppLocalizations.globalText('Commandes'),
                ),
                SizedBox(height: 18),
                _OrderNavItem(
                  icon: Icons.sell_outlined,
                  label: AppLocalizations.globalText('Produits'),
                ),
                SizedBox(height: 18),
                _OrderNavItem(
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

class _OrderNavItem extends StatelessWidget {
  _OrderNavItem({required this.icon, required this.label});

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

class _OrderContent extends StatelessWidget {
  _OrderContent({
    required this.clientName,
    required this.clientCompany,
    required this.categories,
    required this.hoveredCategoryId,
    required this.onHover,
    required this.onExitHover,
    required this.onOpenProducts,
    required this.onBack,
    required this.compact,
  });

  final String clientName;
  final String clientCompany;
  final List<_OrderCategory> categories;
  final int? hoveredCategoryId;
  final ValueChanged<int> onHover;
  final VoidCallback onExitHover;
  final ValueChanged<_OrderCategory> onOpenProducts;
  final VoidCallback onBack;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(top: 20, right: 30, child: _DotPattern()),
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 22 : 28,
            compact ? 24 : 24,
            compact ? 22 : 28,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: onBack,
                icon: Icon(Icons.arrow_back, size: 20),
                label: Text(
                  AppLocalizations.globalText('Retour à la liste des clients'),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Color(0xFFE8EDF5),
                  foregroundColor: _NewOrderScreenState._textDark,
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: compact ? 28 : 34),
              Text(
                AppLocalizations.globalText('Nouvelle Commande'),
                style: TextStyle(
                  color: Colors.black,
                  fontSize: compact ? 26 : 30,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Pour le client : $clientName - $clientCompany',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 16),
              Divider(color: Color(0xFFE2E7F0)),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.globalText('Catégories de Produits'),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        color: Color(0xFF2684B8),
                        size: 34,
                      ),
                      Positioned(
                        top: -7,
                        right: -8,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Color(0xFFE83A3A),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '0',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 22),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: compact ? double.infinity : 760,
                    child: GridView.builder(
                      padding: EdgeInsets.only(bottom: 12),
                      itemCount: categories.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: compact ? 1 : 3,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 18,
                        childAspectRatio: compact ? 1.45 : .92,
                      ),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isHovered = hoveredCategoryId == category.id;
                        return _CategoryCard(
                          category: category,
                          showButton: compact || isHovered,
                          onHover: () => onHover(category.id),
                          onExit: onExitHover,
                          onOpenProducts: () => onOpenProducts(category),
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.globalText('© 2024 PréVente.'),
                style: TextStyle(
                  color: _NewOrderScreenState._textDark,
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

class _CategoryCard extends StatelessWidget {
  _CategoryCard({
    required this.category,
    required this.showButton,
    required this.onHover,
    required this.onExit,
    required this.onOpenProducts,
  });

  final _OrderCategory category;
  final bool showButton;
  final VoidCallback onHover;
  final VoidCallback onExit;
  final VoidCallback onOpenProducts;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHover(),
      onExit: (_) => onExit(),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 160),
        padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Color(
                0xFF193A70,
              ).withValues(alpha: showButton ? .12 : .08),
              blurRadius: showButton ? 18 : 12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Text(category.icon, style: TextStyle(fontSize: 64))),
            Spacer(),
            Text(
              category.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              category.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black,
                fontSize: 15,
                height: 1.1,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 12),
            AnimatedOpacity(
              opacity: showButton ? 1 : 0,
              duration: Duration(milliseconds: 120),
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  onPressed: showButton ? onOpenProducts : null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: Color(0xFFE8F5FF),
                    disabledBackgroundColor: Colors.transparent,
                    foregroundColor: Color(0xFF164260),
                    disabledForegroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(AppLocalizations.globalText('Voir Produits')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductsByCategoryScreen extends StatelessWidget {
  ProductsByCategoryScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.categoryId,
    required this.categoryName,
  });

  final int clientId;
  final String clientName;
  final int categoryId;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3F7FF),
      appBar: AppBar(
        title: Text(categoryName),
        backgroundColor: Colors.white,
        foregroundColor: _NewOrderScreenState._textDark,
        elevation: 0,
      ),
      body: Center(
        child: Card(
          elevation: 0,
          margin: EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'Produits de $categoryName\nClient : $clientName\nID client : $clientId | ID catégorie : $categoryId',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _NewOrderScreenState._textDark,
                fontSize: 18,
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
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

class _OrderCategory {
  _OrderCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final int id;
  final String title;
  final String description;
  final String icon;

  static final defaults = [
    _OrderCategory(
      id: 1,
      title: 'Thé Vert Premium',
      description: 'Gamme premium',
      icon: 'TP',
    ),
    _OrderCategory(
      id: 2,
      title: 'Thé Vert Classique',
      description: 'Gamme classique',
      icon: 'TC',
    ),
  ];
}
