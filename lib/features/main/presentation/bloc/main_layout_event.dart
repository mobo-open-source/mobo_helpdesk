part of 'main_layout_bloc.dart';

/// Base class for all events related to [MainLayoutBloc].
///
/// Events represent user or system actions that trigger state changes
/// in the Main Layout feature.
class MainLayoutEvent {}

/// Event triggered to load the current user profile and access data.
///
/// This event initiates:
/// - Fetching user details from the repository/use case
/// - Checking user access permissions
/// - Updating UI state with profile information
class LoadUser extends MainLayoutEvent {}
