import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/shop_entities.dart';
import '../../../domain/repositories/shop_repository.dart';
import '../../../domain/usecases/record_invoice_usecase.dart';

class CartLine extends Equatable {
  final Product product;
  final double qty;
  const CartLine({required this.product, this.qty = 1});

  double get total => product.sellPrice * qty;
  double get cost => product.buyPrice * qty;

  @override
  List<Object?> get props => [product.id, qty];
}

class InvoicesState extends Equatable {
  final bool loading;
  final List<Invoice> invoices;
  final List<Product> catalog;
  final List<CartLine> cart;
  final String? partyId;
  final double paid;
  final double discount;

  const InvoicesState({
    this.loading = false,
    this.invoices = const [],
    this.catalog = const [],
    this.cart = const [],
    this.partyId,
    this.paid = 0,
    this.discount = 0,
  });

  double get cartTotal => cart.fold(0, (s, l) => s + l.total);

  double totalFor(String kind) => kind == 'sale'
      ? cartTotal
      : cart.fold(0, (s, l) => s + l.cost);

  InvoicesState copyWith({
    bool? loading,
    List<Invoice>? invoices,
    List<Product>? catalog,
    List<CartLine>? cart,
    String? partyId,
    double? paid,
    double? discount,
    bool clearParty = false,
  }) {
    return InvoicesState(
      loading: loading ?? this.loading,
      invoices: invoices ?? this.invoices,
      catalog: catalog ?? this.catalog,
      cart: cart ?? this.cart,
      partyId: clearParty ? null : (partyId ?? this.partyId),
      paid: paid ?? this.paid,
      discount: discount ?? this.discount,
    );
  }

  @override
  List<Object?> get props => [loading, invoices, catalog, cart, partyId, paid, discount];
}

class InvoicesCubit extends Cubit<InvoicesState> {
  InvoicesCubit(this._repo, this._recordInvoice) : super(const InvoicesState());
  final ShopRepository _repo;
  final RecordInvoiceUseCase _recordInvoice;
  final _uuid = const Uuid();

  Future<void> loadHistory(String kind) async {
    emit(state.copyWith(loading: true));
    final invoices = await _repo.getInvoices(kind);
    final catalog = await _repo.getProducts();
    emit(state.copyWith(loading: false, invoices: invoices, catalog: catalog));
  }

  void startNew() {
    emit(state.copyWith(cart: const [], partyId: null, paid: 0, discount: 0, clearParty: true));
  }

  void addToCart(Product p) {
    final cart = List<CartLine>.of(state.cart);
    final i = cart.indexWhere((l) => l.product.id == p.id);
    if (i >= 0) {
      cart[i] = CartLine(product: p, qty: cart[i].qty + 1);
    } else {
      cart.add(CartLine(product: p));
    }
    emit(state.copyWith(cart: cart));
  }

  void setQty(String productId, double qty) {
    if (qty <= 0) {
      emit(state.copyWith(
          cart: state.cart.where((l) => l.product.id != productId).toList()));
      return;
    }
    emit(state.copyWith(
        cart: state.cart
            .map((l) => l.product.id == productId ? CartLine(product: l.product, qty: qty) : l)
            .toList()));
  }

  void setParty(String? id) => emit(state.copyWith(partyId: id, clearParty: id == null));
  void setPaid(double v) => emit(state.copyWith(paid: v));
  void setDiscount(double v) => emit(state.copyWith(discount: v));

  /// Saves the cart as an invoice of [kind] ('sale' | 'purchase').
  /// For purchases the item price roles are swapped (we pay buyPrice).
  Future<String?> save(String kind) async {
    if (state.cart.isEmpty) return 'السلة فارغة';
    final total = state.totalFor(kind) - state.discount;
    if (total < 0) return 'الخصم أكبر من الإجمالي';
    if (state.paid < 0 || state.paid > total) return 'المدفوع غير صحيح';

    final id = _uuid.v4();
    final items = state.cart
        .map((l) => InvoiceItem(
              id: _uuid.v4(),
              invoiceId: id,
              productId: l.product.id,
              productName: l.product.name,
              qty: l.qty,
              buyPrice: l.product.buyPrice,
              sellPrice: kind == 'sale' ? l.product.sellPrice : l.product.buyPrice,
            ))
        .toList();
    await _recordInvoice(
      Invoice(
        id: id,
        kind: kind,
        partyId: state.partyId,
        total: total,
        paid: state.paid,
        discount: state.discount,
        date: DateTime.now().millisecondsSinceEpoch,
      ),
      items,
    );
    emit(state.copyWith(cart: const [], partyId: null, paid: 0, discount: 0, clearParty: true));
    await loadHistory(kind);
    return null;
  }
}
