import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/shop_entities.dart';
import '../../domain/entities/shop_snapshot.dart';
import '../../domain/repositories/sync_gateway.dart';

/// [SyncGateway] backed by Supabase. Tags every row with the owner's user id
/// on the way out, and strips it again on the way back in - the rest of the
/// app never needs to know that column exists.
class SupabaseSyncGateway implements SyncGateway {
  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<void> push(ShopSnapshot snapshot, String ownerId) async {
    await _upsert('categories', snapshot.categories.map((e) => e.toMap()), ownerId);
    await _upsert('products', snapshot.products.map((e) => e.toMap()), ownerId);
    await _upsert('parties', snapshot.parties.map((e) => e.toMap()), ownerId);
    await _upsert('invoices', snapshot.invoices.map((e) => e.toMap()), ownerId);
    await _upsert(
        'invoice_items', snapshot.invoiceItems.map((e) => e.toMap()), ownerId);
    await _upsert('expenses', snapshot.expenses.map((e) => e.toMap()), ownerId);
  }

  Future<void> _upsert(
      String table, Iterable<Map<String, Object?>> rows, String ownerId) async {
    final list = rows.map((r) => {...r, 'user_id': ownerId}).toList();
    if (list.isEmpty) return;
    await _client.from(table).upsert(list);
  }

  @override
  Future<ShopSnapshot> pull(String ownerId) async {
    return ShopSnapshot(
      categories: await _fetch('categories', ownerId, Category.fromMap),
      products: await _fetch('products', ownerId, Product.fromMap),
      parties: await _fetch('parties', ownerId, Party.fromMap),
      invoices: await _fetch('invoices', ownerId, Invoice.fromMap),
      invoiceItems:
          await _fetch('invoice_items', ownerId, InvoiceItem.fromMap),
      expenses: await _fetch('expenses', ownerId, Expense.fromMap),
    );
  }

  Future<List<T>> _fetch<T>(
    String table,
    String ownerId,
    T Function(Map<String, Object?>) fromMap,
  ) async {
    final rows = await _client.from(table).select().eq('user_id', ownerId);
    return rows.map((r) {
      final map = Map<String, Object?>.from(r as Map)..remove('user_id');
      return fromMap(map);
    }).toList();
  }
}
