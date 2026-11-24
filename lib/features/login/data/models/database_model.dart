import '../../domain/entities/database_entity.dart';

/// A data model representing a database.
///
/// This model extends [DatabaseEntity] and is used to map
/// raw data into a structured object within the application.
class DatabaseModel extends DatabaseEntity {
  DatabaseModel({required super.name});

  /// Creates a [DatabaseModel] instance from a JSON value.
  ///
  /// The [dbName] parameter represents the database name
  /// received from an API response or other data source.
  ///
  /// Returns a [DatabaseModel] object with the provided name.
  factory DatabaseModel.fromJson(String dbName) {
    return DatabaseModel(name: dbName);
  }
}
