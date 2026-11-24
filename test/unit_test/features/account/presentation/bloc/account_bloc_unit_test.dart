import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobo_helpdesk/features/account/domain/entities/profile_entity.dart';
import 'package:mobo_helpdesk/features/account/domain/usecases/biometric_usecase.dart';
import 'package:mobo_helpdesk/features/account/domain/usecases/profile_usecase.dart';
import 'package:mobo_helpdesk/features/account/domain/usecases/setting_usecase.dart';
import 'package:mobo_helpdesk/features/account/domain/usecases/switch_account_usecase.dart';
import 'package:mobo_helpdesk/features/account/presentation/bloc/account_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockProfileUseCase extends Mock implements ProfileUseCase {}

class MockSwitchAccountUseCase extends Mock implements SwitchAccountUseCase {}

class MockSettingUseCase extends Mock implements SettingUseCase {}

class MockBiometricUseCase extends Mock implements BiometricUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AccountBloc bloc;
  late MockProfileUseCase mockProfileUseCase;
  late MockSwitchAccountUseCase mockSwitchAccountUseCase;
  late MockSettingUseCase mockSettingUseCase;
  late MockBiometricUseCase mockBiometricUseCase;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockProfileUseCase = MockProfileUseCase();
    mockSwitchAccountUseCase = MockSwitchAccountUseCase();
    mockSettingUseCase = MockSettingUseCase();
    mockBiometricUseCase = MockBiometricUseCase();
    bloc = AccountBloc(
      mockProfileUseCase,
      mockSwitchAccountUseCase,
      mockSettingUseCase,
      mockBiometricUseCase,
    );
  });

  setUpAll(() {
    registerFallbackValue(ImageSource.gallery);
  });

  group('AccountBloc - Load Profile Data', () {
    blocTest<AccountBloc, AccountState>(
      'emits loading and then profile + country data',
      build: () {
        final mockProfile = ProfileEntity(
          id: 1,
          name: 'Marc',
          partnerId: 10,
          phone: '1234567890',
          mail: 'marc@test.com',
          contactAddress: 'Address',
          companyId: null,
          street: 'Street 1',
          street2: 'Street 2',
          stateId: [5, 'Kerala'],
          countryId: [91, 'India'],
          image: '',
          website: '',
          function: '',
          mobile: '9999999999',
        );
        when(
          () => mockProfileUseCase.loadProfile(),
        ).thenAnswer((_) async => mockProfile);

        when(() => mockProfileUseCase.loadCountry()).thenAnswer(
          (_) async => [
            {'id': 91, 'name': 'India'},
          ],
        );

        when(() => mockProfileUseCase.loadState(91)).thenAnswer(
          (_) async => [
            {'id': 5, 'name': 'Kerala'},
          ],
        );

        return bloc;
      },
      act: (bloc) => bloc.add(ProfileDataLoad()),
      expect: () => [
        isA<AccountState>().having((s) => s.isLoading, 'isLoading', true),

        isA<AccountState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.data?.name, 'name', 'Marc')
            .having((s) => s.selectedCountryId, 'countryId', 91)
            .having((s) => s.selectedStateId, 'stateId', 5),

        isA<AccountState>().having((s) => s.states.isNotEmpty, 'states', true),
      ],
      verify: (_) {
        verify(() => mockProfileUseCase.loadProfile()).called(1);
        verify(() => mockProfileUseCase.loadCountry()).called(1);
        verify(() => mockProfileUseCase.loadState(91)).called(1);
      },
    );

    blocTest<AccountBloc, AccountState>(
      'emits error when loadProfile throws exception',
      build: () {
        when(
          () => mockProfileUseCase.loadProfile(),
        ).thenThrow(Exception('Failed'));

        return bloc;
      },
      act: (bloc) => bloc.add(ProfileDataLoad()),
      expect: () => [
        isA<AccountState>().having((s) => s.isLoading, 'isLoading', true),

        isA<AccountState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.error?['title'], 'title', 'Error')
            .having(
              (s) => s.error?['description'],
              'description',
              contains('Exception: Failed'),
            ),
      ],
      verify: (_) {
        verify(() => mockProfileUseCase.loadProfile()).called(1);
      },
    );
  });

  group('AccountBloc - Switch Account', () {
    blocTest<AccountBloc, AccountState>(
      'emits loading then success (the app restarts, so no profile reload)',
      build: () {
        final mockProfile = ProfileEntity(
          id: 1,
          name: 'Marc',
          partnerId: 10,
          phone: '1234567890',
          mail: 'marc@test.com',
          contactAddress: 'Address',
          companyId: null,
          street: 'Street 1',
          street2: 'Street 2',
          stateId: [],
          countryId: [],
          image: '',
          website: '',
          function: '',
          mobile: '9999999999',
        );
        when(
          () => mockSwitchAccountUseCase.switchAccount(any()),
        ).thenAnswer((_) async => true);

        when(
          () => mockProfileUseCase.loadProfile(),
        ).thenAnswer((_) async => mockProfile);

        when(
          () => mockProfileUseCase.loadCountry(),
        ).thenAnswer((_) async => []);

        return bloc;
      },
      act: (bloc) => bloc.add(SwitchAccountEvent({'id': 1})),
      expect: () => [
        isA<AccountState>().having(
          (s) => s.configurationStatus,
          'status',
          ConfigurationStatus.loading,
        ),
        isA<AccountState>().having(
          (s) => s.configurationStatus,
          'status',
          ConfigurationStatus.success,
        ),
      ],
    );

    blocTest<AccountBloc, AccountState>(
      'emits failure when switch account throws exception',
      build: () {
        when(
          () => mockSwitchAccountUseCase.switchAccount(any()),
        ).thenThrow(Exception('Switch failed'));

        return bloc;
      },
      act: (bloc) => bloc.add(SwitchAccountEvent({'id': 1})),
      expect: () => [
        isA<AccountState>().having(
          (s) => s.configurationStatus,
          'status',
          ConfigurationStatus.loading,
        ),
        isA<AccountState>()
            .having(
              (s) => s.configurationStatus,
              'status',
              ConfigurationStatus.failure,
            )
            .having(
              (s) => s.message,
              'message',
              contains('Exception: Switch failed'),
            )
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) {
        verify(() => mockSwitchAccountUseCase.switchAccount(any())).called(1);
      },
    );
  });

  group('AccountBloc - Load Settings', () {
    blocTest<AccountBloc, AccountState>(
      'emits loading then success with settings data',
      build: () {
        when(() => mockSettingUseCase.loadLanguages()).thenAnswer(
          (_) async => [
            {'code': 'en', 'name': 'English'},
          ],
        );

        when(() => mockSettingUseCase.loadCurrencies()).thenAnswer(
          (_) async => [
            {'code': 'USD', 'name': 'Dollar'},
          ],
        );

        when(() => mockSettingUseCase.loadTimezones()).thenAnswer(
          (_) async => [
            {'code': 'IST', 'name': 'India'},
          ],
        );
        return bloc;
      },
      act: (bloc) => bloc.add(LoadSettingsEvent()),
      expect: () => [
        isA<AccountState>().having(
          (s) => s.configurationStatus,
          'status',
          ConfigurationStatus.loading,
        ),
        isA<AccountState>()
            .having(
              (s) => s.configurationStatus,
              'status',
              ConfigurationStatus.success,
            )
            .having((s) => s.languages.length, 'languages', 1)
            .having((s) => s.currencies.length, 'currencies', 1)
            .having((s) => s.timezones.length, 'timezones', 1)
            .having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(() => mockSettingUseCase.loadLanguages()).called(1);
        verify(() => mockSettingUseCase.loadCurrencies()).called(1);
        verify(() => mockSettingUseCase.loadTimezones()).called(1);
      },
    );

    blocTest<AccountBloc, AccountState>(
      'emits failure when settings API throws error',
      build: () {
        when(
          () => mockSettingUseCase.loadLanguages(),
        ).thenThrow(Exception('API failed'));

        return bloc;
      },
      act: (bloc) => bloc.add(LoadSettingsEvent()),
      expect: () => [
        isA<AccountState>().having(
          (s) => s.configurationStatus,
          'status',
          ConfigurationStatus.loading,
        ),
        isA<AccountState>()
            .having(
              (s) => s.configurationStatus,
              'status',
              ConfigurationStatus.failure,
            )
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.error?['title'], 'title', 'Error')
            .having(
              (s) => s.error?['description'],
              'description',
              'Unable to fetch',
            ),
      ],
      verify: (_) {
        verify(() => mockSettingUseCase.loadLanguages()).called(1);
      },
    );
  });

  group('AccountBloc - Update Language', () {
    blocTest<AccountBloc, AccountState>(
      'emits success state when language update is successful',
      build: () {
        when(
          () => mockSettingUseCase.updateLanguage(any()),
        ).thenAnswer((_) async => true);
        return bloc;
      },
      act: (bloc) => bloc.add(UpdateLanguageEvent('en_US', 'English')),
      expect: () => [
        isA<AccountState>()
            .having((s) => s.selectedLanguage, 'selectedLanguage', 'English')
            .having(
              (s) => s.message,
              'message',
              'Language updated successfully',
            )
            .having((s) => s.isSuccess, 'isSuccess', true),
      ],
      verify: (_) async {
        verify(() => mockSettingUseCase.updateLanguage('en_US')).called(1);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('language'), 'English');
      },
    );

    blocTest<AccountBloc, AccountState>(
      'emits error state when language update fails',
      build: () {
        when(
          () => mockSettingUseCase.updateLanguage(any()),
        ).thenThrow(Exception('Update failed'));
        return bloc;
      },
      act: (bloc) => bloc.add(UpdateLanguageEvent('en_US', 'English')),
      expect: () => [
        isA<AccountState>()
            .having((s) => s.isError, 'isError', true)
            .having((s) => s.message, 'message', contains('Exception')),
      ],
      verify: (_) async {
        verify(() => mockSettingUseCase.updateLanguage('en_US')).called(1);
      },
    );
  });

  group('AccountBloc - Update Currency', () {
    blocTest<AccountBloc, AccountState>(
      'emits success state when currency update is successful',
      build: () => bloc,
      act: (bloc) => bloc.add(UpdateCurrencyEvent('INR')),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<AccountState>()
            .having((s) => s.selectedCurrency, 'selectedCurrency', 'INR')
            .having(
              (s) => s.message,
              'message',
              'Currency updated successfully',
            )
            .having((s) => s.isSuccess, 'isSuccess', true),
      ],
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('currency'), 'INR');
      },
    );
  });

  group('AccountBloc - Update Timezone', () {
    blocTest<AccountBloc, AccountState>(
      'emits success state when timezone update is successful',
      build: () {
        when(
          () => mockSettingUseCase.updateTz(any()),
        ).thenAnswer((_) async => true);
        return bloc;
      },
      act: (bloc) => bloc.add(UpdateTimezoneEvent('UTC')),
      expect: () => [
        isA<AccountState>()
            .having((s) => s.selectedTimezone, 'selectedTimezone', 'UTC')
            .having(
              (s) => s.message,
              'message',
              'Timezone updated successfully',
            )
            .having((s) => s.isSuccess, 'isSuccess', true),
      ],
      verify: (_) async {
        verify(() => mockSettingUseCase.updateTz('UTC')).called(1);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('timezone'), 'UTC');
      },
    );

    blocTest<AccountBloc, AccountState>(
      'emits error state when timezone update fails',
      build: () {
        when(
          () => mockSettingUseCase.updateTz(any()),
        ).thenThrow(Exception('Update failed'));
        return bloc;
      },
      act: (bloc) => bloc.add(UpdateTimezoneEvent('UTC')),
      expect: () => [
        isA<AccountState>()
            .having((s) => s.isError, 'isError', true)
            .having((s) => s.message, 'message', contains('Exception')),
      ],
      verify: (_) async {
        verify(() => mockSettingUseCase.updateTz('UTC')).called(1);
      },
    );
  });

  group('AccountBloc - Select Profile Image', () {
    blocTest<AccountBloc, AccountState>(
      'emits state with image bytes when image is picked successfully',
      build: () {
        final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);

        when(
          () => mockProfileUseCase.imagePick(any()),
        ).thenAnswer((_) async => fakeBytes);
        return bloc;
      },
      act: (bloc) => bloc.add(PickImageEvent(ImageSource.gallery)),
      expect: () => [
        isA<AccountState>().having(
          (s) => s.profileImageBytes,
          'imageBytes',
          isNotNull,
        ),
      ],
      verify: (_) async {
        verify(
          () => mockProfileUseCase.imagePick(ImageSource.gallery),
        ).called(1);
      },
    );

    blocTest<AccountBloc, AccountState>(
      'does not emit when image is null',
      build: () {
        when(
          () => mockProfileUseCase.imagePick(any()),
        ).thenAnswer((_) async => null);

        return bloc;
      },
      act: (bloc) => bloc.add(PickImageEvent(ImageSource.gallery)),
      expect: () => [],
    );

    blocTest<AccountBloc, AccountState>(
      'emits error when image picking fails',
      build: () {
        when(
          () => mockProfileUseCase.imagePick(any()),
        ).thenThrow(Exception('Picking failed'));

        return bloc;
      },
      act: (bloc) => bloc.add(PickImageEvent(ImageSource.gallery)),
      expect: () => [
        isA<AccountState>()
            .having((s) => s.isError, 'isError', true)
            .having((s) => s.message, 'message', 'Failed to pick image'),
      ],
    );
  });

  group('AccountBloc - Update Profile', () {
    blocTest<AccountBloc, AccountState>(
      'emits success when profile updated successfully',
      build: () {
        final fakeProfile = ProfileEntity(
          id: 1,
          name: 'Marc',
          partnerId: 1,
          phone: '0796810',
          mail: 'marc@gmail.com',
          contactAddress: '17 Stamford Road, Kirkton, United Kingdom',
          companyId: 1,
          street: '17 Stamford Road',
          street2: 'Kirkton',
          stateId: 2,
          countryId: 1,
          image: '',
          website: 'www.marc.com',
          function: 'consultant',
          mobile: '0798875',
        );
        when(
          () => mockProfileUseCase.updateUserAddress(any(), any()),
        ).thenAnswer((_) async => {'success': true, 'error': null});
        when(
          () => mockProfileUseCase.loadProfile(),
        ).thenAnswer((_) async => fakeProfile);
        return bloc;
      },
      act: (bloc) => bloc.add(
        UpdateProfile(
          partnerId: 1,
          name: 'Marc Demo',
          mail: 'marcdemo@gmail.com',
          phone: '07986946810',
          mobile: '07986946875',
          street1: '24 Coast Rd',
          street2: 'Kirkton',
          countryId: 1,
          stateId: 2,
        ),
      ),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<AccountState>().having((s) => s.isSaving, 'isSaving', true),
        isA<AccountState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.data, 'data', isNotNull)
            .having((s) => s.message, 'message', 'Profile updated successfully')
            .having((s) => s.isSuccess, 'isSuccess', true),
      ],
      verify: (_) async {
        verify(() => mockProfileUseCase.updateUserAddress(any(), 1)).called(1);
        verify(() => mockProfileUseCase.loadProfile()).called(1);
      },
    );

    blocTest<AccountBloc, AccountState>(
      'emits error message when profile updated fails',
      build: () {
        when(
          () => mockProfileUseCase.updateUserAddress(any(), any()),
        ).thenAnswer(
          (_) async => {'success': false, 'error': 'Failed to update address'},
        );
        return bloc;
      },
      act: (bloc) => bloc.add(
        UpdateProfile(
          partnerId: 1,
          name: 'Marc Demo',
          mail: 'marcdemo@gmail.com',
          phone: '07986946810',
          mobile: '07986946875',
          street1: '24 Coast Rd',
          street2: 'Kirkton',
          countryId: 1,
          stateId: 2,
        ),
      ),
      expect: () => [
        isA<AccountState>().having((s) => s.isSaving, 'isSaving', true),
        isA<AccountState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.message, 'message', 'Failed to update address')
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) async {
        verify(() => mockProfileUseCase.updateUserAddress(any(), 1)).called(1);
      },
    );

    blocTest<AccountBloc, AccountState>(
      'emits error when exception occurs during profile update',
      build: () {
        when(
          () => mockProfileUseCase.updateUserAddress(any(), any()),
        ).thenThrow(Exception('Update failed'));
        return bloc;
      },
      act: (bloc) => bloc.add(
        UpdateProfile(
          partnerId: 1,
          name: 'Marc Demo',
          mail: 'marcdemo@gmail.com',
          phone: '07986946810',
          mobile: '07986946875',
          street1: '24 Coast Rd',
          street2: 'Kirkton',
          countryId: 1,
          stateId: 2,
        ),
      ),
      expect: () => [
        isA<AccountState>().having((s) => s.isSaving, 'isSaving', true),
        isA<AccountState>()
            .having((s) => s.isSaving, 'isSaving', false)
            .having((s) => s.message, 'message', contains('Exception'))
            .having((s) => s.isError, 'isError', true),
      ],
      verify: (_) async {
        verify(() => mockProfileUseCase.updateUserAddress(any(), 1)).called(1);
      },
    );
  });
}
