import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../models/vault_item_model.dart';
import '../services/vault_security_service.dart';
import '../services/vault_storage_service.dart';

final vaultSecurityServiceProvider = Provider<VaultSecurityService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return VaultSecurityService(preferences: prefs);
});

final vaultStorageServiceProvider = Provider<VaultStorageService>((ref) {
  final db = ref.watch(databaseProvider);
  final security = ref.watch(vaultSecurityServiceProvider);
  return VaultStorageService(db: db, security: security);
});

class VaultSessionUnlockedNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  void unlock() => state = true;
  void lock() => state = false;
  void toggle() => state = !state;
}

final vaultSessionUnlockedProvider =
    NotifierProvider<VaultSessionUnlockedNotifier, bool>(() {
  return VaultSessionUnlockedNotifier();
});

class VaultCategoryFilterNotifier extends Notifier<VaultCategory?> {
  @override
  VaultCategory? build() => null;
  void setCategory(VaultCategory? cat) => state = cat;
}

final vaultCategoryFilterProvider =
    NotifierProvider<VaultCategoryFilterNotifier, VaultCategory?>(
  VaultCategoryFilterNotifier.new,
);

class VaultSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String q) => state = q;
}

final vaultSearchQueryProvider =
    NotifierProvider<VaultSearchQueryNotifier, String>(
  VaultSearchQueryNotifier.new,
);

final vaultItemsStreamProvider = StreamProvider<List<VaultItem>>((ref) {
  final storage = ref.watch(vaultStorageServiceProvider);
  return storage.watchAllItems();
});

final vaultFilteredItemsProvider = Provider<List<VaultItem>>((ref) {
  final itemsAsync = ref.watch(vaultItemsStreamProvider);
  final items = itemsAsync.value ?? [];
  final selectedCategory = ref.watch(vaultCategoryFilterProvider);
  final query = ref.watch(vaultSearchQueryProvider).trim().toLowerCase();

  return items.where((item) {
    if (selectedCategory != null && item.category != selectedCategory) {
      return false;
    }
    if (query.isNotEmpty) {
      final titleMatch = item.title.toLowerCase().contains(query);
      final subtitleMatch = item.subtitle?.toLowerCase().contains(query) ?? false;
      final categoryMatch = item.category.displayName.toLowerCase().contains(query);
      return titleMatch || subtitleMatch || categoryMatch;
    }
    return true;
  }).toList();
});

final vaultItemCountProvider = Provider<int>((ref) {
  final items = ref.watch(vaultItemsStreamProvider).value;
  return items?.length ?? 0;
});
