import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_prevente/data/mock_presales_data.dart';
import 'package:gestion_prevente/screens/admin/admin_screens.dart';

void main() {
  test('AdminUserStore add / edit / toggle / reset / delete / filter', () {
    final store = AdminUserStore();
    final seeded = store.all.length;

    // create
    const id = 9999;
    store.upsert(
      MockUserProfile(
        id: id,
        name: 'Test User',
        email: 'test@x.ma',
        phone: '0',
        password: 'abc',
        role: MockUserRole.commercial,
      ),
    );
    expect(store.all.length, seeded + 1);

    // toggle active (immutable model -> fresh instance)
    store.setActive(id, false);
    expect(store.all.firstWhere((u) => u.id == id).isActive, false);

    // reset password
    store.resetPassword(id);
    expect(store.all.firstWhere((u) => u.id == id).password, '123456');

    // filters
    expect(store.filter(query: 'test user').length, 1);
    expect(
      store.filter(role: MockUserRole.admin).every((u) => u.role == MockUserRole.admin),
      true,
    );
    expect(store.filter(active: false).any((u) => u.id == id), true);

    // delete
    store.remove(id);
    expect(store.all.length, seeded);
  });
}
