/// Represents a database entity in the application.
///
/// This class is a core domain entity that holds basic information
/// about a database, primarily its [name]. It is used across layers
/// such as data, domain, and presentation.
class DatabaseEntity {
  final String name;

  DatabaseEntity({required this.name});
}
