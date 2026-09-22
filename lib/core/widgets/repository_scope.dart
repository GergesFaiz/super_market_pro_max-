import 'package:flutter/material.dart';

import '../data/shop_repository.dart';

/// Single inherited accessor for [ShopRepository] (avoids a provider package).
class RepositoryScope extends InheritedWidget {
  final ShopRepository repository;
  const RepositoryScope({super.key, required this.repository, required super.child});

  static ShopRepository of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'RepositoryScope not found above this widget');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(RepositoryScope oldWidget) => false;
}
