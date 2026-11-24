/// Core domain entity representing a user in the main layout feature.
///
/// This class is part of the domain layer and defines the essential
/// properties of a user without any dependency on data sources,
/// frameworks, or external APIs.
///
/// It acts as a pure business object used across the application.
///
/// Fields:
/// - [id]: Unique identifier of the user
/// - [name]: Display name of the user
/// - [mail]: Email address of the user
/// - [image]: Profile image (base64 or URL encoded string)
///
/// This entity is used by repositories, use cases, and presentation layers
/// to ensure a consistent and framework-independent data structure.
class MainLayoutEntity {
  final int id;
  final String name;
  final String mail;
  final String image;

  MainLayoutEntity({
    required this.id,
    required this.name,
    required this.mail,
    required this.image,
  });
}
