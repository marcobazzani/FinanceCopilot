import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../utils/logger.dart';

final _log = getLogger('RegisteredEventService');

class RegisteredEventService {
  final AppDatabase _db;

  RegisteredEventService(this._db);

  Stream<List<RegisteredEvent>> watchAll() {
    return (_db.select(_db.registeredEvents)
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .watch();
  }

  Future<List<RegisteredEvent>> getAll() {
    return (_db.select(_db.registeredEvents)
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .get();
  }

  Future<RegisteredEvent> getById(int id) {
    return (_db.select(_db.registeredEvents)
          ..where((e) => e.id.equals(id)))
        .getSingle();
  }

  Stream<RegisteredEvent> watchById(int id) {
    return (_db.select(_db.registeredEvents)
          ..where((e) => e.id.equals(id)))
        .watchSingle();
  }

  Future<int> create({
    required DateTime date,
    required RegisteredEventType type,
    required double amount,
    String description = '',
    bool isPersonal = true,
  }) async {
    _log.info('create: type=$type, amount=$amount, date=$date');
    return _db.into(_db.registeredEvents).insert(
      RegisteredEventsCompanion.insert(
        date: date,
        type: type,
        amount: amount,
        description: Value(description),
        isPersonal: Value(isPersonal),
      ),
    );
  }

  Future<bool> update(int id, RegisteredEventsCompanion companion) async {
    _log.info('update: id=$id');
    final rows = await (_db.update(_db.registeredEvents)
          ..where((e) => e.id.equals(id)))
        .write(companion);
    return rows > 0;
  }

  Future<int> delete(int id) async {
    _log.warning('delete: registered event id=$id');
    return (_db.delete(_db.registeredEvents)
          ..where((e) => e.id.equals(id)))
        .go();
  }
}
