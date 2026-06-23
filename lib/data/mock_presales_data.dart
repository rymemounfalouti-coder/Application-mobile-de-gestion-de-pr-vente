import 'package:flutter/material.dart';

enum MockUserRole { commercial, manager, admin }

enum ClientStatus { toVisit, visited, inactive }

enum ClientRisk { low, medium, high }

enum TourVisitStatus { visited, upcoming }

enum OrderStatus { pending, synced, delivered, cancelled }

extension ClientStatusLabel on ClientStatus {
  String get label {
    return switch (this) {
      ClientStatus.toVisit => 'A visiter',
      ClientStatus.visited => 'Visité',
      ClientStatus.inactive => 'Inactif',
    };
  }
}

extension ClientRiskLabel on ClientRisk {
  String get label {
    return switch (this) {
      ClientRisk.low => 'Faible',
      ClientRisk.medium => 'Moyen',
      ClientRisk.high => 'Élevé',
    };
  }
}

extension TourVisitStatusLabel on TourVisitStatus {
  String get label {
    return switch (this) {
      TourVisitStatus.visited => 'Visité',
      TourVisitStatus.upcoming => 'À venir',
    };
  }
}

extension OrderStatusLabel on OrderStatus {
  String get label {
    return switch (this) {
      OrderStatus.pending => 'En attente',
      OrderStatus.synced => 'Synchronisée',
      OrderStatus.delivered => 'Livrée',
      OrderStatus.cancelled => 'Annulée',
    };
  }
}

class MockPreSalesData {
  const MockPreSalesData._();

  static const users = {
    'ahmed@presales.ma': MockUserProfile(
      id: 1,
      email: 'ahmed@presales.ma',
      name: 'Ahmed Benali',
      phone: '0522 12 34 56',
      password: '123456',
      role: MockUserRole.commercial,
    ),
    'manager@presales.ma': MockUserProfile(
      id: 2,
      email: 'manager@presales.ma',
      name: 'Manager BPS',
      phone: '0522 98 76 54',
      password: '123456',
      role: MockUserRole.manager,
    ),
    'admin@presales.ma': MockUserProfile(
      id: 5,
      email: 'admin@presales.ma',
      name: 'Admin PreSales',
      phone: '0522 00 00 00',
      password: '123456',
      role: MockUserRole.admin,
    ),
    'sara@presales.ma': MockUserProfile(
      id: 3,
      email: 'sara@presales.ma',
      name: 'Sara El Amrani',
      phone: '0537 44 22 18',
      password: '123456',
      role: MockUserRole.commercial,
    ),
    'mehdi@presales.ma': MockUserProfile(
      id: 4,
      email: 'mehdi@presales.ma',
      name: 'Mehdi Alaoui',
      phone: '0522 33 44 55',
      password: '123456',
      role: MockUserRole.commercial,
    ),
  };

  static const Map<int, CommercialDashboardData> commercialDashboards = {};

  static const teaSudClients = [
    CommercialClient(
      id: 101,
      commercialId: 1,
      clientCode: 'CL001',
      name: 'Carrefour Maarif',
      businessType: 'Supermarchés & Grandes Surfaces',
      category: 'Supermarchés & Grandes Surfaces',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'CM',
      phone: '0522 25 41 60',
      email: 'contact@carrefour-maarif.ma',
      address: 'Boulevard Al Massira Al Khadra, Maarif, Casablanca',
      contactName: 'Youssef El Amrani',
      latitude: 33.5852,
      longitude: -7.6358,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 102,
      commercialId: 1,
      clientCode: 'CL002',
      name: 'Marjane Californie',
      businessType: 'Supermarchés & Grandes Surfaces',
      category: 'Supermarchés & Grandes Surfaces',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'MC',
      phone: '0522 87 63 21',
      email: 'contact@marjane-californie.ma',
      address: 'Route de Bouskoura, Californie, Casablanca',
      contactName: 'Nadia Benjelloun',
      latitude: 33.5164,
      longitude: -7.6389,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 103,
      commercialId: 1,
      clientCode: 'CL003',
      name: 'Aswak Assalam Ain Sebaa',
      businessType: 'Supermarchés & Grandes Surfaces',
      category: 'Supermarchés & Grandes Surfaces',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'AA',
      phone: '0522 35 18 74',
      email: 'contact@aswak-ainsebaa.ma',
      address: 'Boulevard Chefchaouni, Ain Sebaa, Casablanca',
      contactName: 'Karim Tazi',
      latitude: 33.6068,
      longitude: -7.5312,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 104,
      commercialId: 1,
      clientCode: 'CL004',
      name: 'Atlas Distribution',
      businessType: 'Grossistes',
      category: 'Grossistes',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'AD',
      phone: '0522 61 24 80',
      email: 'contact@atlas-distribution.ma',
      address: 'Boulevard Mohammed V, Casablanca',
      contactName: 'Ahmed El Fassi',
      latitude: 33.5894,
      longitude: -7.6039,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 105,
      commercialId: 1,
      clientCode: 'CL005',
      name: 'Grossiste Al Baraka',
      businessType: 'Grossistes',
      category: 'Grossistes',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'GB',
      phone: '0522 44 78 12',
      email: 'contact@grossiste-baraka.ma',
      address: 'Rue Ibn Tachfine, Derb Sultan, Casablanca',
      contactName: 'Mustapha Rami',
      latitude: 33.5738,
      longitude: -7.6057,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 106,
      commercialId: 1,
      clientCode: 'CL006',
      name: 'Grossiste El Fath',
      businessType: 'Grossistes',
      category: 'Grossistes',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'GF',
      phone: '0522 70 19 35',
      email: 'contact@grossiste-elfath.ma',
      address: 'Quartier Industriel Sidi Bernoussi, Casablanca',
      contactName: 'Hassan Berrada',
      latitude: 33.6152,
      longitude: -7.4938,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 107,
      commercialId: 1,
      clientCode: 'CL007',
      name: 'Chaouia Distribution',
      businessType: 'Grossistes',
      category: 'Grossistes',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'CD',
      phone: '0522 91 36 48',
      email: 'contact@chaouia-distribution.ma',
      address: 'Zone Industrielle Lissasfa, Casablanca',
      contactName: 'Omar Lamrani',
      latitude: 33.5357,
      longitude: -7.7041,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 108,
      commercialId: 1,
      clientCode: 'CL008',
      name: 'Épicerie Al Amal',
      businessType: 'Épiceries',
      category: 'Épiceries',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'EA',
      phone: '0612 34 56 78',
      email: 'alamal@presales.ma',
      address: 'Rue de Fès, Hay Hassani, Casablanca',
      contactName: 'Said Amrani',
      latitude: 33.5661,
      longitude: -7.6782,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 109,
      commercialId: 1,
      clientCode: 'CL009',
      name: 'Épicerie Nour',
      businessType: 'Épiceries',
      category: 'Épiceries',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'EN',
      phone: '0619 45 22 11',
      email: 'nour@presales.ma',
      address: 'Boulevard Ghandi, Casablanca',
      contactName: 'Rachid Nouri',
      latitude: 33.5679,
      longitude: -7.6508,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 110,
      commercialId: 1,
      clientCode: 'CL010',
      name: 'Épicerie Al Wifaq',
      businessType: 'Épiceries',
      category: 'Épiceries',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'EW',
      phone: '0622 18 90 43',
      email: 'wifaq@presales.ma',
      address: 'Quartier Al Wifaq, Sidi Maarouf, Casablanca',
      contactName: 'Mounir El Kadiri',
      latitude: 33.5296,
      longitude: -7.6501,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 111,
      commercialId: 1,
      clientCode: 'CL011',
      name: 'Épicerie Al Baraka',
      businessType: 'Épiceries',
      category: 'Épiceries',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'EB',
      phone: '0628 77 41 09',
      email: 'epicerie.baraka@presales.ma',
      address: 'Avenue 2 Mars, Casablanca',
      contactName: 'Abdelilah Hadi',
      latitude: 33.5714,
      longitude: -7.6253,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 112,
      commercialId: 1,
      clientCode: 'CL012',
      name: 'Épicerie El Khair',
      businessType: 'Épiceries',
      category: 'Épiceries',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'EK',
      phone: '0631 64 20 85',
      email: 'elkhair@presales.ma',
      address: 'Boulevard Oued Oum Rabia, Casablanca',
      contactName: 'Yassine El Kabbaj',
      latitude: 33.5489,
      longitude: -7.6744,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 113,
      commercialId: 1,
      clientCode: 'CL013',
      name: 'Épicerie Salam',
      businessType: 'Épiceries',
      category: 'Épiceries',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'ES',
      phone: '0636 29 77 54',
      email: 'salam@presales.ma',
      address: 'Hay Mohammadi, Casablanca',
      contactName: 'Brahim Alaoui',
      latitude: 33.5939,
      longitude: -7.5687,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 114,
      commercialId: 1,
      clientCode: 'CL014',
      name: 'Épicerie Al Fajr',
      businessType: 'Épiceries',
      category: 'Épiceries',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'EF',
      phone: '0640 83 15 69',
      email: 'alfajr@presales.ma',
      address: 'Ain Chock, Casablanca',
      contactName: 'Hamza El Mansouri',
      latitude: 33.5452,
      longitude: -7.6236,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 115,
      commercialId: 1,
      clientCode: 'CL015',
      name: 'Épicerie Yasmine',
      businessType: 'Épiceries',
      category: 'Épiceries',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'EY',
      phone: '0647 50 31 22',
      email: 'yasmine@presales.ma',
      address: 'Hay Moulay Rachid, Casablanca',
      contactName: 'Imane Tahiri',
      latitude: 33.5584,
      longitude: -7.5559,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 116,
      commercialId: 1,
      clientCode: 'CL016',
      name: 'Café Atlas',
      businessType: 'Cafés & Restaurants',
      category: 'Cafés & Restaurants',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'CA',
      phone: '0522 48 90 16',
      email: 'cafe.atlas@presales.ma',
      address: 'Boulevard Zerktouni, Casablanca',
      contactName: 'Anas Bakkali',
      latitude: 33.5867,
      longitude: -7.6321,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 117,
      commercialId: 1,
      clientCode: 'CL017',
      name: 'Café Andalous',
      businessType: 'Cafés & Restaurants',
      category: 'Cafés & Restaurants',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'CA',
      phone: '0522 31 70 94',
      email: 'cafe.andalous@presales.ma',
      address: 'Rue Normandie, Bourgogne, Casablanca',
      contactName: 'Samir Bennani',
      latitude: 33.6031,
      longitude: -7.6494,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 118,
      commercialId: 1,
      clientCode: 'CL018',
      name: 'Café Palmier',
      businessType: 'Cafés & Restaurants',
      category: 'Cafés & Restaurants',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'CP',
      phone: '0522 39 62 58',
      email: 'cafe.palmier@presales.ma',
      address: 'Quartier Palmier, Casablanca',
      contactName: 'Mehdi Idrissi',
      latitude: 33.5762,
      longitude: -7.6353,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 119,
      commercialId: 1,
      clientCode: 'CL019',
      name: 'Restaurant Riad Casablanca',
      businessType: 'Cafés & Restaurants',
      category: 'Cafés & Restaurants',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'RC',
      phone: '0522 66 45 10',
      email: 'riad.casablanca@presales.ma',
      address: 'Ancienne Médina, Casablanca',
      contactName: 'Laila Fadili',
      latitude: 33.5994,
      longitude: -7.6172,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
    CommercialClient(
      id: 120,
      commercialId: 1,
      clientCode: 'CL020',
      name: 'Restaurant Saveurs du Maroc',
      businessType: 'Cafés & Restaurants',
      category: 'Cafés & Restaurants',
      city: 'Casablanca',
      status: ClientStatus.visited,
      initials: 'SM',
      phone: '0522 73 84 26',
      email: 'saveurs.maroc@presales.ma',
      address: 'Boulevard de la Corniche, Ain Diab, Casablanca',
      contactName: 'Amine Saidi',
      latitude: 33.5946,
      longitude: -7.6769,
      creditLimit: 0,
      discount: 0,
      balance: 0,
      lastOrderDate: '-',
      risk: ClientRisk.low,
      orders: [],
      documents: [],
    ),
  ];

  static const commercialClients = {
    1: teaSudClients,
    3: teaSudClients,
    4: teaSudClients,
  };
  static MockUserProfile? userByEmail(String email) {
    return users[email.trim().toLowerCase()];
  }

  static List<MockUserProfile> commercialUsers({bool includeInactive = false}) {
    return users.values
        .where(
          (user) =>
              user.role == MockUserRole.commercial &&
              (includeInactive || user.isActive),
        )
        .toList();
  }

  static CommercialDashboardData dashboardForEmail(String email) {
    final user = userByEmail(email);
    return dashboardForUser(user) ?? CommercialDashboardData.empty();
  }

  static List<CommercialClient> clientsForEmail(String email) {
    final user = userByEmail(email);
    return clientsForUser(user);
  }

  static List<TourVisit> tourVisitsForEmail(String email) {
    final user = userByEmail(email);
    return tourVisitsForUser(user);
  }

  static List<CommercialOrder> ordersForEmail(String email) {
    final user = userByEmail(email);
    return ordersForUser(user);
  }

  static CommercialDashboardData? dashboardForUser(MockUserProfile? user) {
    if (user == null || user.role != MockUserRole.commercial) return null;
    return CommercialDashboardData.empty();
  }

  static List<CommercialClient> clientsForUser(MockUserProfile? user) {
    if (user == null || user.role != MockUserRole.commercial) return const [];
    return commercialClients[user.id] ?? const [];
  }

  static List<TourVisit> tourVisitsForUser(MockUserProfile? user) {
    if (user == null || user.role != MockUserRole.commercial) return const [];
    return const [];
  }

  static List<CommercialOrder> ordersForUser(MockUserProfile? user) {
    if (user == null || user.role != MockUserRole.commercial) return const [];
    return const [];
  }

  static const Map<int, List<CommercialOrder>> commercialOrders = {};

  static const Map<int, List<TourVisit>> commercialTourVisits = {};

  static const orderProducts = [
    OrderProduct(
      id: 1,
      name: 'Assil Chaara Premium 200g',
      reference: '41022-200',
      category: 'Thé vert en filaments',
      weight: '200g',
      image: 'assets/images/products/chaara_premium_200g.jpeg',
      unitPrice: 22,
      prixStandard: 22,
      prixGrossiste: 20,
      prixGMS: 19,
      prixCHR: 21,
      stock: 120,
      icon: Icons.local_cafe_rounded,
      imageColor: Color(0xFF15803D),
    ),
    OrderProduct(
      id: 2,
      name: 'Assil Chaara Premium 250g',
      reference: '41022-250',
      category: 'Thé vert en filaments',
      weight: '250g',
      image: 'assets/images/products/chaara_premium_250g.jpeg',
      unitPrice: 27,
      prixStandard: 27,
      prixGrossiste: 25,
      prixGMS: 24,
      prixCHR: 26,
      stock: 100,
      icon: Icons.local_cafe_rounded,
      imageColor: Color(0xFF15803D),
    ),
    OrderProduct(
      id: 3,
      name: 'Assil Chaara Premium 500g',
      reference: '41022-500',
      category: 'Thé vert en filaments',
      weight: '500g',
      image: 'assets/images/products/chaara_premium_500g.jpeg',
      unitPrice: 52,
      prixStandard: 52,
      prixGrossiste: 48,
      prixGMS: 47,
      prixCHR: 50,
      stock: 90,
      icon: Icons.local_cafe_rounded,
      imageColor: Color(0xFF15803D),
    ),
    OrderProduct(
      id: 4,
      name: 'Assil Chaara Premium 1kg',
      reference: '41022-1000',
      category: 'Thé vert en filaments',
      weight: '1kg',
      image: 'assets/images/products/chaara_premium_1kg.jpeg',
      unitPrice: 98,
      prixStandard: 98,
      prixGrossiste: 92,
      prixGMS: 90,
      prixCHR: 95,
      stock: 70,
      icon: Icons.local_cafe_rounded,
      imageColor: Color(0xFF15803D),
    ),
    OrderProduct(
      id: 5,
      name: 'Assil Chaara Premium 2kg',
      reference: '41022-2000',
      category: 'Thé vert en filaments',
      weight: '2kg',
      image: 'assets/images/products/chaara_premium_2kg.jpeg',
      unitPrice: 185,
      prixStandard: 185,
      prixGrossiste: 175,
      prixGMS: 170,
      prixCHR: 180,
      stock: 50,
      icon: Icons.local_cafe_rounded,
      imageColor: Color(0xFF15803D),
    ),
    OrderProduct(
      id: 6,
      name: 'Assil Chaara Classique 200g',
      reference: '9305-200',
      category: 'Thé vert en filaments',
      weight: '200g',
      image: 'assets/images/products/chaara_classique_200g.jpeg',
      unitPrice: 18,
      prixStandard: 18,
      prixGrossiste: 16,
      prixGMS: 15,
      prixCHR: 17,
      stock: 140,
      icon: Icons.local_cafe_rounded,
      imageColor: Color(0xFF65A30D),
    ),
    OrderProduct(
      id: 7,
      name: 'Assil Chaara Classique 250g',
      reference: '9305-250',
      category: 'Thé vert en filaments',
      weight: '250g',
      image: 'assets/images/products/chaara_classique_250g.jpeg',
      unitPrice: 23,
      prixStandard: 23,
      prixGrossiste: 21,
      prixGMS: 20,
      prixCHR: 22,
      stock: 130,
      icon: Icons.local_cafe_rounded,
      imageColor: Color(0xFF65A30D),
    ),
    OrderProduct(
      id: 8,
      name: 'Assil Chaara Classique 500g',
      reference: '9305-500',
      category: 'Thé vert en filaments',
      weight: '500g',
      image: 'assets/images/products/chaara_classique_500.jpeg',
      unitPrice: 44,
      prixStandard: 44,
      prixGrossiste: 40,
      prixGMS: 39,
      prixCHR: 42,
      stock: 110,
      icon: Icons.local_cafe_rounded,
      imageColor: Color(0xFF65A30D),
    ),
    OrderProduct(
      id: 9,
      name: 'Assil Chaara Classique 1kg',
      reference: '9305-1000',
      category: 'Thé vert en filaments',
      weight: '1kg',
      image: 'assets/images/products/chaara_classique_1kg.jpeg',
      unitPrice: 85,
      prixStandard: 85,
      prixGrossiste: 79,
      prixGMS: 77,
      prixCHR: 82,
      stock: 80,
      icon: Icons.local_cafe_rounded,
      imageColor: Color(0xFF65A30D),
    ),
    OrderProduct(
      id: 10,
      name: 'Assil Chaara Classique 2kg',
      reference: '9305-2000',
      category: 'Thé vert en filaments',
      weight: '2kg',
      image: 'assets/images/products/chaara_classique_2kg.jpeg',
      unitPrice: 160,
      prixStandard: 160,
      prixGrossiste: 150,
      prixGMS: 145,
      prixCHR: 155,
      stock: 60,
      icon: Icons.local_cafe_rounded,
      imageColor: Color(0xFF65A30D),
    ),
    OrderProduct(
      id: 11,
      name: 'Assil Al-Lamma Premium 200g',
      reference: 'ALP-200',
      category: 'Thé vert en grains Gunpowder',
      weight: '200g',
      image: 'assets/images/products/allamma_premium_200g.jpeg',
      unitPrice: 20,
      prixStandard: 20,
      prixGrossiste: 18,
      prixGMS: 17,
      prixCHR: 19,
      stock: 120,
      icon: Icons.grain_rounded,
      imageColor: Color(0xFF047857),
    ),
    OrderProduct(
      id: 12,
      name: 'Assil Al-Lamma Premium 250g',
      reference: 'ALP-250',
      category: 'Thé vert en grains Gunpowder',
      weight: '250g',
      image: 'assets/images/products/allamma_premium_250g.jpeg',
      unitPrice: 25,
      prixStandard: 25,
      prixGrossiste: 23,
      prixGMS: 22,
      prixCHR: 24,
      stock: 110,
      icon: Icons.grain_rounded,
      imageColor: Color(0xFF047857),
    ),
    OrderProduct(
      id: 13,
      name: 'Assil Al-Lamma Premium 500g',
      reference: 'ALP-500',
      category: 'Thé vert en grains Gunpowder',
      weight: '500g',
      image: 'assets/images/products/allamma_premium_500g.jpeg',
      unitPrice: 49,
      prixStandard: 49,
      prixGrossiste: 45,
      prixGMS: 44,
      prixCHR: 47,
      stock: 95,
      icon: Icons.grain_rounded,
      imageColor: Color(0xFF047857),
    ),
    OrderProduct(
      id: 14,
      name: 'Assil Al-Lamma Premium 1kg',
      reference: 'ALP-1000',
      category: 'Thé vert en grains Gunpowder',
      weight: '1kg',
      image: 'assets/images/products/allamma_premium_1kg.jpeg',
      unitPrice: 92,
      prixStandard: 92,
      prixGrossiste: 86,
      prixGMS: 84,
      prixCHR: 89,
      stock: 75,
      icon: Icons.grain_rounded,
      imageColor: Color(0xFF047857),
    ),
    OrderProduct(
      id: 15,
      name: 'Assil Al-Lamma Premium 2kg',
      reference: 'ALP-2000',
      category: 'Thé vert en grains Gunpowder',
      weight: '2kg',
      image: 'assets/images/products/allamma_premium_2kg.jpeg',
      unitPrice: 175,
      prixStandard: 175,
      prixGrossiste: 165,
      prixGMS: 160,
      prixCHR: 170,
      stock: 55,
      icon: Icons.grain_rounded,
      imageColor: Color(0xFF047857),
    ),
    OrderProduct(
      id: 16,
      name: 'Assil Al-Lamma Classique 200g',
      reference: 'ALC-200',
      category: 'Thé vert en grains Gunpowder',
      weight: '200g',
      image: 'assets/images/products/allamma_classique_200g.jpeg',
      unitPrice: 16,
      prixStandard: 16,
      prixGrossiste: 14,
      prixGMS: 13,
      prixCHR: 15,
      stock: 150,
      icon: Icons.grain_rounded,
      imageColor: Color(0xFF84CC16),
    ),
    OrderProduct(
      id: 17,
      name: 'Assil Al-Lamma Classique 250g',
      reference: 'ALC-250',
      category: 'Thé vert en grains Gunpowder',
      weight: '250g',
      image: 'assets/images/products/allamma_classique_250g.jpeg',
      unitPrice: 21,
      prixStandard: 21,
      prixGrossiste: 19,
      prixGMS: 18,
      prixCHR: 20,
      stock: 140,
      icon: Icons.grain_rounded,
      imageColor: Color(0xFF84CC16),
    ),
    OrderProduct(
      id: 18,
      name: 'Assil Al-Lamma Classique 500g',
      reference: 'ALC-500',
      category: 'Thé vert en grains Gunpowder',
      weight: '500g',
      image: 'assets/images/products/allamma_classique_500g.jpeg',
      unitPrice: 40,
      prixStandard: 40,
      prixGrossiste: 36,
      prixGMS: 35,
      prixCHR: 38,
      stock: 120,
      icon: Icons.grain_rounded,
      imageColor: Color(0xFF84CC16),
    ),
    OrderProduct(
      id: 19,
      name: 'Assil Al-Lamma Classique 1kg',
      reference: 'ALC-1000',
      category: 'Thé vert en grains Gunpowder',
      weight: '1kg',
      image: 'assets/images/products/allamma_classique_1kg.jpeg',
      unitPrice: 78,
      prixStandard: 78,
      prixGrossiste: 72,
      prixGMS: 70,
      prixCHR: 75,
      stock: 90,
      icon: Icons.grain_rounded,
      imageColor: Color(0xFF84CC16),
    ),
    OrderProduct(
      id: 20,
      name: 'Assil Al-Lamma Classique 2kg',
      reference: 'ALC-2000',
      category: 'Thé vert en grains Gunpowder',
      weight: '2kg',
      image: 'assets/images/products/allamma_classique_2kg.jpeg',
      unitPrice: 150,
      prixStandard: 150,
      prixGrossiste: 140,
      prixGMS: 135,
      prixCHR: 145,
      stock: 70,
      icon: Icons.grain_rounded,
      imageColor: Color(0xFF84CC16),
    ),
  ];
}

class MockUserProfile {
  const MockUserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.password,
    required this.role,
    this.isActive = true,
  });

  final int id;
  final String email;
  final String name;
  final String phone;
  final String password;
  final MockUserRole role;
  final bool isActive;
}

class CommercialDashboardData {
  const CommercialDashboardData({
    required this.summary,
    required this.activities,
  });

  factory CommercialDashboardData.empty() {
    return const CommercialDashboardData(
      summary: CommercialDashboardSummary(
        monthlyTarget: 1,
        achievedAmount: 0,
        monthlyOrders: 0,
        revenue: 0,
        dailyVisitsDone: 0,
        dailyVisitsTotal: 1,
        conversionRate: 0,
        ordersEvolution: 0,
        revenueEvolution: 0,
        visitsEvolution: 0,
        conversionEvolution: 0,
      ),
      activities: [],
    );
  }

  final CommercialDashboardSummary summary;
  final List<CommercialActivity> activities;
}

class CommercialDashboardSummary {
  const CommercialDashboardSummary({
    required this.monthlyTarget,
    required this.achievedAmount,
    required this.monthlyOrders,
    required this.revenue,
    required this.dailyVisitsDone,
    required this.dailyVisitsTotal,
    required this.conversionRate,
    required this.ordersEvolution,
    required this.revenueEvolution,
    required this.visitsEvolution,
    required this.conversionEvolution,
  });

  final double monthlyTarget;
  final double achievedAmount;
  final int monthlyOrders;
  final double revenue;
  final int dailyVisitsDone;
  final int dailyVisitsTotal;
  final int conversionRate;
  final int ordersEvolution;
  final int revenueEvolution;
  final int visitsEvolution;
  final int conversionEvolution;

  double get monthlyProgress => (achievedAmount / monthlyTarget).clamp(0, 1);
  double get dailyVisitProgress =>
      (dailyVisitsDone / dailyVisitsTotal).clamp(0, 1);
}

class CommercialActivity {
  const CommercialActivity({
    this.commercialId = 0,
    required this.time,
    required this.client,
    required this.city,
    required this.color,
  });

  final int commercialId;
  final String time;
  final String client;
  final String city;
  final Color color;
}

class TourVisit {
  const TourVisit({
    this.commercialId = 0,
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.time,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.mapX,
    required this.mapY,
  });

  final int commercialId;
  final int id;
  final int clientId;
  final String clientName;
  final String time;
  final TourVisitStatus status;
  final double latitude;
  final double longitude;
  final double mapX;
  final double mapY;
}

class CommercialOrder {
  const CommercialOrder({
    this.commercialId = 0,
    required this.id,
    required this.orderNumber,
    required this.clientName,
    required this.date,
    required this.productsCount,
    required this.total,
    required this.status,
    required this.items,
  });

  final int commercialId;
  final int id;
  final String orderNumber;
  final String clientName;
  final String date;
  final int productsCount;
  final double total;
  final OrderStatus status;
  final List<OrderLine> items;
}

class OrderLine {
  const OrderLine({
    required this.productName,
    required this.quantity,
    required this.total,
  });

  final String productName;
  final int quantity;
  final double total;
}

class CommercialClient {
  const CommercialClient({
    this.commercialId = 0,
    this.clientCode = '',
    this.businessType = 'Commerce général',
    this.category = 'Commerce général',
    this.contactName = '',
    this.latitude = 33.5731,
    this.longitude = -7.5898,
    required this.id,
    required this.name,
    required this.city,
    required this.status,
    required this.initials,
    required this.phone,
    required this.email,
    required this.address,
    required this.creditLimit,
    required this.discount,
    required this.balance,
    required this.lastOrderDate,
    required this.risk,
    required this.orders,
    required this.documents,
  });

  final int commercialId;
  final String clientCode;
  final String businessType;
  final String category;
  final String contactName;
  final double latitude;
  final double longitude;
  final int id;
  final String name;
  final String city;
  final ClientStatus status;
  final String initials;
  final String phone;
  final String email;
  final String address;
  final double creditLimit;
  final double discount;
  final double balance;
  final String lastOrderDate;
  final ClientRisk risk;
  final List<ClientOrder> orders;
  final List<ClientDocument> documents;

  CommercialClient copyWith({
    int? commercialId,
    String? clientCode,
    String? businessType,
    String? category,
    String? contactName,
    double? latitude,
    double? longitude,
    int? id,
    String? name,
    String? city,
    ClientStatus? status,
    String? initials,
    String? phone,
    String? email,
    String? address,
    double? creditLimit,
    double? discount,
    double? balance,
    String? lastOrderDate,
    ClientRisk? risk,
    List<ClientOrder>? orders,
    List<ClientDocument>? documents,
  }) {
    return CommercialClient(
      commercialId: commercialId ?? this.commercialId,
      clientCode: clientCode ?? this.clientCode,
      businessType: businessType ?? this.businessType,
      category: category ?? this.category,
      contactName: contactName ?? this.contactName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      status: status ?? this.status,
      initials: initials ?? this.initials,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      creditLimit: creditLimit ?? this.creditLimit,
      discount: discount ?? this.discount,
      balance: balance ?? this.balance,
      lastOrderDate: lastOrderDate ?? this.lastOrderDate,
      risk: risk ?? this.risk,
      orders: orders ?? this.orders,
      documents: documents ?? this.documents,
    );
  }
}

class ClientOrder {
  const ClientOrder({
    required this.reference,
    required this.date,
    required this.amount,
  });

  final String reference;
  final String date;
  final double amount;
}

class ClientDocument {
  const ClientDocument({
    required this.type,
    required this.reference,
    required this.date,
  });

  final String type;
  final String reference;
  final String date;
}

class OrderProduct {
  const OrderProduct({
    required this.id,
    required this.name,
    required this.reference,
    required this.category,
    this.weight = '',
    this.image = '',
    required this.unitPrice,
    double? prixStandard,
    double? prixGrossiste,
    double? prixGMS,
    double? prixCHR,
    required this.stock,
    required this.icon,
    required this.imageColor,
  }) : prixStandard = prixStandard ?? unitPrice,
       prixGrossiste = prixGrossiste ?? unitPrice,
       prixGMS = prixGMS ?? unitPrice,
       prixCHR = prixCHR ?? unitPrice;

  final int id;
  final String name;
  final String reference;
  final String category;
  final String weight;
  final String image;
  final double unitPrice;
  final double prixStandard;
  final double prixGrossiste;
  final double prixGMS;
  final double prixCHR;
  final int stock;
  final IconData icon;
  final Color imageColor;
}

class ValidatedOrder {
  const ValidatedOrder({
    required this.orderNumber,
    required this.client,
    required this.date,
    this.deliveryDate,
    required this.total,
    required this.status,
    required this.items,
  });

  final String orderNumber;
  final CommercialClient client;
  final DateTime date;
  final DateTime? deliveryDate;
  final double total;
  final String status;
  final List<ValidatedOrderItem> items;
}

class ValidatedOrderItem {
  const ValidatedOrderItem({
    required this.product,
    required this.quantity,
    required this.lineTotal,
    this.unitPriceApplied,
    this.tariffLabel = 'Standard',
    this.discountRate = 0,
    this.discountAmount = 0,
    this.grossTotal,
  });

  final OrderProduct product;
  final int quantity;
  final double lineTotal;
  final double? unitPriceApplied;
  final String tariffLabel;
  final double discountRate;
  final double discountAmount;
  final double? grossTotal;
}
