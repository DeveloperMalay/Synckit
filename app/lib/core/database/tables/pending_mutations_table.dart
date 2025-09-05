import 'package:drift/drift.dart';

@DataClassName('PendingMutation')
class PendingMutations extends Table {
  TextColumn get id => text()();
  TextColumn get endpoint => text()();
  TextColumn get method => text()(); // GET, POST, PUT, DELETE
  TextColumn get payload => text()(); // JSON string
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {id};
}