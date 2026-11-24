part of 'main_layout_bloc.dart';

/// Represents the state of the Main Layout feature.
///
/// This state holds all UI-related data for the main screen, including:
/// - Loading status
/// - User profile information
/// - Profile image (decoded bytes)
/// - Navigation index
/// - Access permission status
///
/// It extends [Equatable] to ensure efficient state comparisons
/// and prevent unnecessary UI rebuilds.
class MainLayoutState extends Equatable {
  final bool isLoading;
  final String userName;
  final int userId;
  final String mail;
  final Uint8List? profileImage;
  final int currentIndex;
  final bool isAccess;

  const MainLayoutState({
    this.isLoading = false,
    this.userName = '',
    this.userId = 0,
    this.mail = '',
    this.profileImage,
    this.currentIndex = 0,
    this.isAccess = false,
  });

  MainLayoutState copyWith({
    bool? isLoading,
    String? userName,
    int? userId,
    String? mail,
    Uint8List? profileImage,
    int? currentIndex,
    bool? isAccess,
  }) {
    return MainLayoutState(
      isLoading: isLoading ?? this.isLoading,
      userName: userName ?? this.userName,
      userId: userId ?? this.userId,
      mail: mail ?? this.mail,
      profileImage: profileImage ?? this.profileImage,
      currentIndex: currentIndex ?? this.currentIndex,
      isAccess: isAccess ?? this.isAccess,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    userName,
    userId,
    mail,
    profileImage,
    currentIndex,
    isAccess,
  ];
}
