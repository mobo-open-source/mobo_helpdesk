import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/features/main/domain/entities/main_layout_entity.dart';
import 'package:mobo_helpdesk/features/main/domain/usecases/main_layout_usecase.dart';
import 'package:mobo_helpdesk/features/main/presentation/bloc/main_layout_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockMainLayoutUseCase extends Mock implements MainLayoutUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MainLayoutBloc bloc;
  late MockMainLayoutUseCase mockMainLayoutUseCase;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    mockMainLayoutUseCase = MockMainLayoutUseCase();
    bloc = MainLayoutBloc(mockMainLayoutUseCase);
  });

  group('MainLayoutBloc - Load User Details', () {
    blocTest<MainLayoutBloc, MainLayoutState>(
      'emits loading and then user data with access',
      build: () {
        when(() => mockMainLayoutUseCase.loadUser()).thenAnswer(
          (_) async => [
            MainLayoutEntity(
              id: 1,
              name: 'Marc',
              mail: 'marc@test.com',
              image: '',
            ),
          ],
        );
        when(
          () => mockMainLayoutUseCase.checkAccess(),
        ).thenAnswer((_) async => true);
        return bloc;
      },
      act: (bloc) => bloc.add(LoadUser()),
      expect: () => [
        const MainLayoutState(isLoading: true),
        isA<MainLayoutState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.userName, 'userName', 'Marc')
            .having((s) => s.mail, 'mail', 'marc@test.com')
            .having((s) => s.userId, 'userId', 1)
            .having((s) => s.isAccess, 'isAccess', true),
      ],
      verify: (_) async {
        verify(() => mockMainLayoutUseCase.loadUser()).called(1);
        verify(() => mockMainLayoutUseCase.checkAccess()).called(1);
      },
    );

    blocTest<MainLayoutBloc, MainLayoutState>(
      'emits loading false with access when no user data',
      build: () {
        when(
          () => mockMainLayoutUseCase.loadUser(),
        ).thenAnswer((_) async => []);

        when(
          () => mockMainLayoutUseCase.checkAccess(),
        ).thenAnswer((_) async => true);

        return bloc;
      },
      act: (bloc) => bloc.add(LoadUser()),
      expect: () => [
        const MainLayoutState(isLoading: true),
        isA<MainLayoutState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.isAccess, 'isAccess', true)
            .having((s) => s.userName, 'userName', '')
            .having((s) => s.userId, 'userId', 0)
            .having((s) => s.mail, 'mail', ''),
      ],
    );

    blocTest<MainLayoutBloc, MainLayoutState>(
      'emits catch error fallback data from SharedPreferences',
      build: () {
        when(
          () => mockMainLayoutUseCase.loadUser(),
        ).thenThrow(Exception('API failed'));
        return bloc;
      },
      setUp: () async {
        SharedPreferences.setMockInitialValues({
          'isSystem': true,
          'userId': 99,
          'userName': 'Cached User',
          'userEmail': 'cached@test.com',
          'userImage': '',
        });
      },
      act: (bloc) => bloc.add(LoadUser()),
      expect: () => [
        const MainLayoutState(isLoading: true),
        isA<MainLayoutState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.userName, 'userName', 'Cached User')
            .having((s) => s.userId, 'userId', 99)
            .having((s) => s.mail, 'mail', 'cached@test.com')
            .having((s) => s.isAccess, 'isAccess', true),
      ],
    );
  });
}
