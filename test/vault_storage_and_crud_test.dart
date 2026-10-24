import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/vault/models/vault_item_model.dart';
import 'package:ascent/features/vault/services/vault_security_service.dart';
import 'package:ascent/features/vault/services/vault_storage_service.dart';

void main() {
  late AppDatabase db;
  late VaultSecurityService security;
  late VaultStorageService storage;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    security = VaultSecurityService.forTesting();
    storage = VaultStorageService(db: db, security: security);
    await storage.init();
  });

  tearDown(() async {
    await db.close();
  });

  group('Vault Storage Service CRUD & Cascading Tests', () {
    test('insert, retrieve and verify encrypted payload', () async {
      final card = VaultItem(
        title: 'HDFC Regalia',
        category: VaultCategory.card,
        subtitle: '•••• 0366',
        fields: {
          'cardholderName': 'Arun Singh',
          'cardNumber': '4532015112830366',
          'expiry': '08/29',
          'cvv': '789',
          'cardBrand': 'Visa',
          'bankName': 'HDFC Bank',
        },
        mediaPaths: ['/tmp/card_front.jpg'],
        isFavorite: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final insertedId = await storage.insertItem(card);
      expect(insertedId, greaterThan(0));

      final fetched = await storage.getItemById(insertedId);
      expect(fetched, isNotNull);
      expect(fetched!.title, 'HDFC Regalia');
      expect(fetched.category, VaultCategory.card);
      expect(fetched.subtitle, '•••• 0366');
      expect(fetched.fields['cardNumber'], '4532015112830366');
      expect(fetched.fields['cvv'], '789');
      expect(fetched.fields['cardBrand'], 'Visa');
      expect(fetched.mediaPaths, contains('/tmp/card_front.jpg'));
      expect(fetched.isFavorite, isTrue);
    });

    test('updateItem modifies fields cleanly and updates timestamp', () async {
      final login = VaultItem(
        title: 'GitHub Work',
        category: VaultCategory.login,
        subtitle: 'arunsingh@github.com',
        fields: {
          'username': 'arunsingh',
          'password': 'InitialPassword123!',
          'website': 'https://github.com',
        },
        mediaPaths: [],
        isFavorite: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await storage.insertItem(login);
      final item = await storage.getItemById(id);

      final updated = item!.copyWith(
        title: 'GitHub Enterprise',
        fields: {
          'username': 'arunsingh',
          'password': 'SuperSecurePassword2026@#',
          'website': 'https://github.com',
        },
        isFavorite: true,
      );

      await storage.updateItem(updated);

      final refetched = await storage.getItemById(id);
      expect(refetched!.title, 'GitHub Enterprise');
      expect(refetched.fields['password'], 'SuperSecurePassword2026@#');
      expect(refetched.isFavorite, isTrue);
    });

    test('deleteItem removes record cleanly', () async {
      final doc = VaultItem(
        title: 'Passport Scan',
        category: VaultCategory.idDoc,
        subtitle: 'Passport • Z1234567',
        fields: {
          'docType': 'Passport',
          'docNumber': 'Z1234567',
          'holderName': 'Arun Singh',
        },
        mediaPaths: [],
        isFavorite: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await storage.insertItem(doc);
      expect(await storage.getItemById(id), isNotNull);

      await storage.deleteItem(id);
      expect(await storage.getItemById(id), isNull);
    });

    test('watchAllItems emits stream updates on change', () async {
      final stream = storage.watchAllItems();
      expect(await stream.first, isEmpty);

      final note = VaultItem(
        title: 'Recovery Seed',
        category: VaultCategory.note,
        subtitle: '12 words backup',
        fields: {'content': 'apple banana cherry dragon elephant fox'},
        mediaPaths: [],
        isFavorite: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await storage.insertItem(note);
      final itemsAfterInsert = await storage.getAllItems();
      expect(itemsAfterInsert.length, 1);
      expect(itemsAfterInsert.first.title, 'Recovery Seed');
    });
  });
}
