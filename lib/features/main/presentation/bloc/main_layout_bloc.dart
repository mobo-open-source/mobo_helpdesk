import 'dart:convert';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobo_helpdesk/core/storage/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/usecases/main_layout_usecase.dart';

part 'main_layout_event.dart';

part 'main_layout_state.dart';

/// BLoC responsible for managing the state of the Main Layout feature.
///
/// This bloc handles:
/// - Loading user profile data from the use case layer
/// - Checking user access permissions
/// - Persisting and retrieving account/session information
/// - Decoding and managing profile image data
///
/// It interacts with:
/// - [MainLayoutUseCase] for business logic
/// - [StorageService] for local persistence
/// - [SharedPreferences] for lightweight session storage
///
/// The bloc emits [MainLayoutState] to update the UI accordingly.
class MainLayoutBloc extends Bloc<MainLayoutEvent, MainLayoutState> {
  final MainLayoutUseCase loadProfileUseCase;

  MainLayoutBloc(this.loadProfileUseCase) : super(const MainLayoutState()) {
    on<LoadUser>(_loadUser);
  }

  /// Handles the [LoadUser] event by fetching user data and access rights.
  ///
  /// Flow:
  /// 1. Sets loading state
  /// 2. Fetches user profile from use case
  /// 3. Checks access permissions
  /// 4. Decodes profile image (base64 → Uint8List)
  /// 5. Saves/updates account in local storage
  /// 6. Emits updated state
  /// 7. Falls back to cached data on error
  ///
  /// Emits:
  /// - Loading state while fetching data
  /// - Updated user profile state on success
  /// - Cached state on failure
  Future<void> _loadUser(LoadUser event, Emitter<MainLayoutState> emit) async {
    final prefs = await SharedPreferences.getInstance();

    emit(state.copyWith(isLoading: true));

    try {
      final profiles = await loadProfileUseCase.loadUser();

      final checkAccess = await loadProfileUseCase.checkAccess();

      if (profiles.isNotEmpty) {
        final profile = profiles.first;
        Uint8List? imageBytes;

        if (profile.image.isNotEmpty) {
          imageBytes = base64Decode(profile.image);
        }

        final currentAccounts = await StorageService().getAccounts();

        final currentUrl = prefs.getString('url') ?? '';
        final currentDb = prefs.getString('database') ?? '';

        final existing = currentAccounts.firstWhere(
          (a) =>
              a['userId'] == profile.id &&
              a['url'] == currentUrl &&
              a['database'] == currentDb,
          orElse: () => {},
        );

        final accountWithImage = {
          ...existing,
          'userId': profile.id,
          'url': currentUrl,
          'database': currentDb,
          // The name too: an edit made in Profile Details must reach the
          // Switch Accounts list, which shows this stored entry.
          if (profile.name.isNotEmpty) 'userName': profile.name,
          'image': profile.image,
        };

        await StorageService().saveAccount(accountWithImage);

        emit(
          state.copyWith(
            isLoading: false,
            userName: profile.name,
            userId: profile.id,
            mail: profile.mail,
            profileImage: imageBytes,
            isAccess: checkAccess,
          ),
        );
      } else {
        emit(state.copyWith(isLoading: false, isAccess: checkAccess));
      }
    } catch (e) {
      final isAccess = prefs.getBool('isSystem') ?? false;
      final id = prefs.getInt('userId');
      final name = prefs.getString('userName');
      final email = prefs.getString('userEmail');
      final imageString = prefs.getString('userImage');

      Uint8List? imageBytes;

      if (imageString != null && imageString.isNotEmpty) {
        try {
          imageBytes = base64Decode(imageString);
        } catch (_) {
          imageBytes = null;
        }
      }
      emit(
        state.copyWith(
          isLoading: false,
          userName: name,
          userId: id,
          mail: email,
          profileImage: imageBytes,
          isAccess: isAccess,
        ),
      );
    }
  }
}
