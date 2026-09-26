import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/shop_entities.dart';
import '../../../domain/repositories/shop_repository.dart';

class PartiesState extends Equatable {
  final bool loading;
  final List<Party> parties;
  const PartiesState({this.loading = false, this.parties = const []});

  @override
  List<Object?> get props => [loading, parties];
}

class PartiesCubit extends Cubit<PartiesState> {
  PartiesCubit(this._repo) : super(const PartiesState());
  final ShopRepository _repo;
  final _uuid = const Uuid();

  Future<void> load(String kind) async {
    emit(const PartiesState(loading: true));
    final list = await _repo.getParties(kind);
    emit(PartiesState(parties: list));
  }

  Future<void> save({String? id, required String name, String phone = '', required String kind}) async {
    await _repo.upsertParty(Party(
      id: id ?? _uuid.v4(),
      name: name,
      phone: phone,
      kind: kind,
      balance: id == null
          ? 0
          : state.parties
              .where((p) => p.id == id)
              .map((p) => p.balance)
              .firstOrNull ?? 0,
    ));
    await load(kind);
  }

  Future<void> remove(String id, String kind) async {
    await _repo.deleteParty(id);
    await load(kind);
  }
}
