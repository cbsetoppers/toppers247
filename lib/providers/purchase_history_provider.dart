import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_provider.dart';
import 'auth_provider.dart';

final purchaseHistoryProvider = StateNotifierProvider<PurchaseHistoryNotifier, List<Map<String, dynamic>>>((ref) {
  return PurchaseHistoryNotifier(ref);
});

class PurchaseHistoryNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final Ref _ref;
  PurchaseHistoryNotifier(this._ref) : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final user = _ref.watch(authProvider).value;
    if (user == null) return;

    final history = await _ref.read(supabaseServiceProvider).fetchPurchaseHistory(user.id);
    
    final productPurchases = history.map<Map<String, dynamic>>((p) => {
      'id': p['id'],
      'name': p['product_name'],
      'code': p['product_code'],
      'amount': p['amount'],
      'date': p['purchase_date'],
      'status': p['status'],
      'fileUrl': p['file_url'],
      'transactionId': p['transaction_id'],
      'type': 'product',
    }).toList();
    
    productPurchases.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
    
    state = productPurchases;
  }

  Future<void> addPurchase({
    required String id,
    required String productName,
    required String productCode,
    required String amount,
    String? fileUrl,
  }) async {
    final user = _ref.read(authProvider).value;
    if (user == null) return;

    await _ref.read(supabaseServiceProvider).savePurchase(
      id: id,
      studentId: user.id,
      productName: productName,
      productCode: productCode,
      amount: amount,
      fileUrl: fileUrl,
    );

    await _loadHistory();
  }
  
  Future<void> refresh() async {
    await _loadHistory();
  }
}
