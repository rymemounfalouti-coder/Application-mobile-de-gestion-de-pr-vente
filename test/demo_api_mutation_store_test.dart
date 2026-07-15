import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_prevente/api_service.dart';

int _id(Map<dynamic, dynamic> row) =>
    (row['id'] ?? row['client_id'] ?? row['user_id'] ?? row['produit_id'])
        as int;

void main() {
  group(
    'ApiService presentation demo store',
    () {
      setUp(ApiService.resetDemoDataForTesting);

      test('company, client and recent activity mutations persist', () async {
        final company = await ApiService.updateCompanyInfo({
          'phone': '0522 99 88 77',
          'address': 'Demo showroom',
        });
        expect(company['name'], 'TeaSud');
        expect((await ApiService.getCompanyInfo())['phone'], '0522 99 88 77');

        final seeded = await ApiService.getClients();
        final maximumSeedId = seeded
            .whereType<Map>()
            .map(_id)
            .fold<int>(0, (maximum, id) => id > maximum ? id : maximum);
        final created = await ApiService.createClient({
          'name': 'Client Demo Persistant',
          'commercial_id': 3,
          'status': 'toVisit',
          'city': 'Rabat',
          'phone': '0600000000',
        });
        final clientId = created['id'] as int;
        expect(clientId, greaterThan(maximumSeedId));
        expect(created['client_id'], clientId);

        final commercialClients = await ApiService.getClients(commercialId: 3);
        expect(commercialClients.any((row) => row['id'] == clientId), isTrue);
        expect(
          (await ApiService.getClients(
            commercialId: 4,
          )).any((row) => row['id'] == clientId),
          isFalse,
        );

        await ApiService.updateClient(clientId, {
          'nom': 'Client Demo Modifie',
          'statut': 'visited',
          'telephone': '0699999999',
        });
        final updated = (await ApiService.getClients(
          commercialId: 3,
        )).firstWhere((row) => row['id'] == clientId);
        expect(updated['nom'], 'Client Demo Modifie');
        expect(updated['computed_status'], 'visited');
        expect(updated['phone'], '0699999999');

        final activity = await ApiService.createCommercialRecentActivity({
          'commercial_id': 3,
          'type_action': 'client_cree',
          'titre': 'Client demo ajoute',
          'description': 'Ajout effectue pendant la presentation',
        });
        expect(activity['id'], isA<int>());
        expect(
          (await ApiService.getCommercialRecentActivities(
            commercialId: 3,
          )).any((row) => row['id'] == activity['id']),
          isTrue,
        );

        await ApiService.deleteClient(clientId);
        expect(
          (await ApiService.getClients()).any((row) => row['id'] == clientId),
          isFalse,
        );
      });

      test(
        'order state, status filters, comments and notifications persist',
        () async {
          final created = await ApiService.createCommande({
            'order_number': 'CMD-DEMO-TEST',
            'client_id': 101,
            'client_name': 'Cafe Atlas',
            'commercial_id': 3,
            'status': 'en_attente',
            'total': 175.5,
            'lines': [
              {
                'product_id': 1,
                'product_name': 'The vert',
                'quantity': 3,
                'unit_price': 58.5,
                'total': 175.5,
              },
            ],
          });
          final orderId = created['id'] as int;
          expect(created['commande_id'], orderId);
          expect(created['facture_id'], orderId);
          expect(created['items'], hasLength(1));
          expect(
            (await ApiService.getFactures()).any((row) => row['id'] == orderId),
            isTrue,
          );
          expect(
            (await ApiService.getCommercialCommandes(
              commercialId: 3,
            )).any((row) => row['id'] == orderId),
            isTrue,
          );
          expect(
            (await ApiService.getManagerCommandes(
              status: 'en_attente',
            )).any((row) => row['id'] == orderId),
            isTrue,
          );

          final notificationsBefore = await ApiService.getNotifications();
          final cancellation = await ApiService.requestCommandeCancellation(
            orderId,
          );
          expect(cancellation['success'], isTrue);
          expect((await ApiService.getCommande(orderId))['status'], 'pending');
          final notificationsAfter = await ApiService.getNotifications();
          expect(notificationsAfter, hasLength(notificationsBefore.length + 1));
          expect(notificationsAfter.first['commande_id'], orderId);
          expect(notificationsAfter.first['is_read'], isFalse);

          await ApiService.updateCommandeStatus(
            orderId,
            'validee',
            managerId: 2,
          );
          expect(
            (await ApiService.getManagerCommandes(
              status: 'pending',
            )).any((row) => row['id'] == orderId),
            isFalse,
          );
          expect(
            (await ApiService.getManagerCommandes(
              status: 'validated',
            )).any((row) => row['id'] == orderId),
            isTrue,
          );
          await expectLater(
            ApiService.requestCommandeCancellation(orderId),
            throwsA(isA<StateError>()),
          );

          await ApiService.addCommandeComment(
            orderId,
            'Commande verifiee',
            managerId: 2,
          );
          final order = await ApiService.getCommande(orderId);
          expect(order['manager_comment'], 'Commande verifiee');
          expect(order['manager_comments'], hasLength(1));

          await ApiService.markNotificationRead(1);
          expect(
            (await ApiService.getNotifications()).firstWhere(
              (row) => row['id'] == 1,
            )['is_read'],
            isTrue,
          );
          final allRead = await ApiService.markAllNotificationsRead(
            managerId: 2,
          );
          expect(allRead.every((row) => row['is_read'] == true), isTrue);
          await ApiService.deleteNotification(2);
          expect(
            (await ApiService.getNotifications()).any((row) => row['id'] == 2),
            isFalse,
          );
        },
      );

      test(
        'user, report and product CRUD preserves generated IDs and data',
        () async {
          final seededUsers = await ApiService.getUsers();
          final maxUserId = seededUsers
              .whereType<Map>()
              .map(_id)
              .fold<int>(0, (maximum, id) => id > maximum ? id : maximum);
          final user = await ApiService.createUser({
            'name': 'Commercial Demo',
            'email': 'commercial.demo@teasud.ma',
            'phone': '0611111111',
            'password': 'demo-pass-1',
            'role': 'commercial',
            'is_active': true,
          });
          final userId = user['id'] as int;
          expect(userId, greaterThan(maxUserId));
          expect(user['user_id'], userId);
          expect(
            (await ApiService.login(
              'commercial.demo@teasud.ma',
              'demo-pass-1',
            ))['id'],
            userId,
          );

          await ApiService.updateUser(userId, {
            'full_name': 'Commercial Demo MAJ',
          });
          await ApiService.updateUserPreferences(userId, {
            'push_notifications': false,
            'language': 'fr',
          });
          final updatedUser = (await ApiService.getUsers()).firstWhere(
            (row) => row['id'] == userId,
          );
          expect(updatedUser['full_name'], 'Commercial Demo MAJ');
          expect(updatedUser['preferences']['language'], 'fr');

          await expectLater(
            ApiService.changePassword(userId, 'incorrect', 'demo-pass-2'),
            throwsA(isA<StateError>()),
          );
          await ApiService.changePassword(userId, 'demo-pass-1', 'demo-pass-2');
          await expectLater(
            ApiService.login('commercial.demo@teasud.ma', 'demo-pass-1'),
            throwsA(isA<Exception>()),
          );
          expect(
            (await ApiService.login(
              'commercial.demo@teasud.ma',
              'demo-pass-2',
            ))['id'],
            userId,
          );
          await ApiService.updateUser(userId, {'active': false});
          await expectLater(
            ApiService.login('commercial.demo@teasud.ma', 'demo-pass-2'),
            throwsA(isA<Exception>()),
          );

          final report = await ApiService.createRapport({
            'commercial_id': userId,
            'commercial_name': 'Commercial Demo MAJ',
            'summary': 'Rapport de demonstration',
            'activities_count': 2,
            'orders_count': 1,
          });
          final reportId = report['id'] as int;
          expect(report['rapport_id'], reportId);
          await ApiService.markRapportRead(reportId);
          await ApiService.addRapportComment(
            reportId,
            'Rapport approuve',
            managerId: 2,
          );
          final storedReport = (await ApiService.getRapports()).firstWhere(
            (row) => row['id'] == reportId,
          );
          expect(storedReport['is_read'], isTrue);
          expect(storedReport['manager_comment'], 'Rapport approuve');

          final seededProducts = await ApiService.getProduits();
          final maxProductId = seededProducts
              .whereType<Map>()
              .map(_id)
              .fold<int>(0, (maximum, id) => id > maximum ? id : maximum);
          final product = await ApiService.createProduit({
            'name': 'The Demo',
            'reference': 'DEMO-001',
            'category': 'The',
            'price': 99.0,
            'stock': 12,
          });
          final productId = product['id'] as int;
          expect(productId, greaterThan(maxProductId));
          expect(product['produit_id'], productId);
          await ApiService.updateProduit(productId, {
            'prix': 109.0,
            'quantite_stock': 8,
          });
          final storedProduct = (await ApiService.getProduits()).firstWhere(
            (row) => row['id'] == productId,
          );
          expect(storedProduct['prix_vente'], 109.0);
          expect(storedProduct['quantite_stock'], 8);

          await ApiService.deleteProduit(productId);
          await ApiService.deleteUser(userId);
          expect(
            (await ApiService.getProduits()).any(
              (row) => row['id'] == productId,
            ),
            isFalse,
          );
          expect(
            (await ApiService.getUsers()).any((row) => row['id'] == userId),
            isFalse,
          );
        },
      );

      test('email and manager ownership filters do not leak records', () async {
        final clientsById = await ApiService.getClients(commercialId: 1);
        final clientsByEmail = await ApiService.getClients(
          commercialEmail: 'AHMED@PRESALES.MA',
        );
        expect(
          clientsByEmail.map((row) => row['id']).toSet(),
          clientsById.map((row) => row['id']).toSet(),
        );
        expect(
          await ApiService.getClients(commercialEmail: 'unknown@presales.ma'),
          isEmpty,
        );
        expect(
          await ApiService.getCommercialCommandes(
            commercialEmail: 'unknown@presales.ma',
          ),
          isEmpty,
        );
        expect(
          await ApiService.getCommercialRecentActivities(
            commercialEmail: 'unknown@presales.ma',
          ),
          isEmpty,
        );

        final managerTenOrder = await ApiService.createCommande({
          'client_name': 'Manager Ten Client',
          'commercial_id': 3,
          'manager_id': 10,
          'status': 'validated',
          'total': 10,
        });
        final managerElevenOrder = await ApiService.createCommande({
          'client_name': 'Manager Eleven Client',
          'commercial_id': 3,
          'manager_id': 11,
          'status': 'validated',
          'total': 11,
        });
        final managerTenRows = await ApiService.getManagerCommandes(
          managerId: 10,
          status: 'validated',
        );
        expect(
          managerTenRows.any((row) => row['id'] == managerTenOrder['id']),
          isTrue,
        );
        expect(
          managerTenRows.any((row) => row['id'] == managerElevenOrder['id']),
          isFalse,
        );

        final pendingOrder = await ApiService.createCommande({
          'client_name': 'Cancellation Owner Client',
          'commercial_id': 3,
          'manager_id': 10,
          'status': 'pending',
          'total': 12,
        });
        final cancellation = await ApiService.requestCommandeCancellation(
          pendingOrder['id'] as int,
        );
        final notificationId = cancellation['notification']['id'] as int;
        expect(
          (await ApiService.getNotifications(
            managerId: 10,
          )).any((row) => row['id'] == notificationId),
          isTrue,
        );
        expect(
          (await ApiService.getNotifications(
            managerId: 11,
          )).any((row) => row['id'] == notificationId),
          isFalse,
        );
        await ApiService.markAllNotificationsRead(managerId: 11);
        expect(
          (await ApiService.getNotifications(
            managerId: 10,
          )).firstWhere((row) => row['id'] == notificationId)['is_read'],
          isFalse,
        );
      });

      test(
        'client aggregates follow order and facture status mutations',
        () async {
          final client = await ApiService.createClient({
            'name': 'Aggregate Demo Client',
            'commercial_id': 3,
            'status': 'toVisit',
          });
          final clientId = client['id'] as int;
          final order = await ApiService.createCommande({
            'client_id': clientId,
            'client_name': 'Aggregate Demo Client',
            'commercial_id': 3,
            'status': 'en_attente',
            'total': 250.0,
            'date': '2026-07-15T12:00:00.000',
          });
          final orderId = order['id'] as int;
          var storedClient = (await ApiService.getClients()).firstWhere(
            (row) => row['id'] == clientId,
          );
          expect(storedClient['orders_count'], 1);
          expect(storedClient['ca_total'], 0);
          expect(storedClient['computed_status'], 'toVisit');
          expect(
            storedClient['computed_last_order_date'],
            contains('2026-07-15'),
          );

          await ApiService.updateFactureStatus(
            orderId,
            'validee',
            managerId: 2,
          );
          final facture = (await ApiService.getFactures()).firstWhere(
            (row) => row['id'] == orderId,
          );
          expect(facture['status'], 'validated');
          storedClient = (await ApiService.getClients()).firstWhere(
            (row) => row['id'] == clientId,
          );
          expect(storedClient['ca_total'], 250.0);
          expect(storedClient['computed_status'], 'visited');

          await ApiService.updateFactureStatus(
            orderId,
            'refusee',
            refusalReason: 'Stock indisponible',
            managerId: 2,
          );
          final refused = await ApiService.getCommande(orderId);
          expect(refused['status'], 'refused');
          expect(refused['refusal_reason'], 'Stock indisponible');
          storedClient = (await ApiService.getClients()).firstWhere(
            (row) => row['id'] == clientId,
          );
          expect(storedClient['ca_total'], 0);
          expect(storedClient['computed_status'], 'toVisit');
        },
      );

      test(
        'generated IDs remain monotonic after deleting newest rows',
        () async {
          final firstClient = await ApiService.createClient({'name': 'First'});
          await ApiService.deleteClient(firstClient['id'] as int);
          final secondClient = await ApiService.createClient({
            'name': 'Second',
          });
          expect(secondClient['id'], greaterThan(firstClient['id'] as int));

          final firstUser = await ApiService.createUser({
            'name': 'First User',
            'email': 'first-id@presales.ma',
            'password': 'password-1',
            'role': 'commercial',
          });
          await ApiService.deleteUser(firstUser['id'] as int);
          final secondUser = await ApiService.createUser({
            'name': 'Second User',
            'email': 'second-id@presales.ma',
            'password': 'password-2',
            'role': 'commercial',
          });
          expect(secondUser['id'], greaterThan(firstUser['id'] as int));

          final firstProduct = await ApiService.createProduit({
            'name': 'First Product',
            'price': 1,
            'stock': 1,
          });
          await ApiService.deleteProduit(firstProduct['id'] as int);
          final secondProduct = await ApiService.createProduit({
            'name': 'Second Product',
            'price': 2,
            'stock': 2,
          });
          expect(secondProduct['id'], greaterThan(firstProduct['id'] as int));

          final order = await ApiService.createCommande({
            'client_name': 'Notification ID Client',
            'commercial_id': 3,
            'status': 'pending',
            'total': 1,
          });
          final firstRequest = await ApiService.requestCommandeCancellation(
            order['id'] as int,
          );
          final firstNotificationId = firstRequest['notification']['id'] as int;
          await ApiService.deleteNotification(firstNotificationId);
          final secondRequest = await ApiService.requestCommandeCancellation(
            order['id'] as int,
          );
          final secondNotificationId =
              secondRequest['notification']['id'] as int;
          expect(secondNotificationId, greaterThan(firstNotificationId));

          await expectLater(
            ApiService.updateClient(999999, {'nom': 'Missing'}),
            throwsA(isA<StateError>()),
          );
        },
      );
    },
    skip: ApiService.demoModeEnabled
        ? false
        : 'Run with --dart-define=DEMO_MODE=true.',
  );
}
