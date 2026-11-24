import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_helpdesk/core/widgets/snackbar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../core/widgets/app_bar_widget.dart';
import '../../data/repositories/url_launcher_repo_impl.dart';
import '../../domain/usecases/url_launcher_usecase.dart';
import '../bloc/account_bloc.dart';
import '../widgets/app_web.dart';
import '../widgets/setting_dropdown_tile.dart';
import '../widgets/setting_section_card.dart';
import '../widgets/setting_section_tap_tile.dart';
import '../widgets/setting_social_button.dart';
import '../widgets/setting_toggle_tile.dart';

/// Application settings screen that allows users to configure:
/// - Appearance (theme mode)
/// - Security (biometric authentication)
/// - Language, currency, and timezone preferences
/// - Cache and storage management
/// - External links and support resources
/// - Social media navigation
///
/// This screen interacts with AccountBloc for state management
/// and uses UrlLauncherUseCase for external navigation.
///
/// It also integrates ThemeServiceProvider for dynamic theme switching.
class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool biometricEnabled = false;

  late UrlLauncherUseCase urlLauncherUseCase;

  @override
  void initState() {
    super.initState();
    _loadBiometricPreference();
    urlLauncherUseCase = UrlLauncherUseCase(UrlLauncherRepoImpl());
    context.read<AccountBloc>().add(LoadSettingsEvent());
  }

  Future<void> _loadBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('biometricEnabled') ?? false;
    if (!mounted) return;
    context.read<AccountBloc>().add(SetBiometricInitial(enabled));
  }

  Future<void> _openInAppWebPage(Uri url, {String? title}) async {
    if (!mounted) return;
    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => InAppWebPage(url: url, title: title),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.showError(context, "Could not open page, Try again later");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeServiceProvider>(context);

    return BlocListener<AccountBloc, AccountState>(
      listenWhen: (prev, curr) =>
          curr.message != null && curr.message != prev.message,
      listener: (context, state) {
        if (state.message != null) {
          if (state.isError == true) {
            CustomSnackBar.showError(context, state.message!);
          } else {
            if (state.isSuccess == true) {
              CustomSnackBar.showSuccess(context, state.message!);
            } else if (state.isInfo == true) {
              CustomSnackBar.showInfo(context, state.message!);
            }
          }
          context.read<AccountBloc>().add(ClearAccountMessage());
        }
      },
      child: Scaffold(
        appBar: AppBarWidget(
          title: "Settings",
          isDark: isDark,
          onBack: () => Navigator.of(context).pop(),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ────────────────────────────────────────────────
                // Appearance Section
                // ────────────────────────────────────────────────
                SettingsSectionCard(
                  title: "Appearance",
                  child: SettingsToggleTile(
                    icon: Icon(
                      Icons.dark_mode_outlined,
                      color: isDark ? Colors.grey.shade400 : Colors.black,
                    ),
                    title: "Dark Mode",
                    subtitle: "Switch between light and dark themes",
                    value: isDark,
                    onChanged: (_) => themeProvider.toggleTheme(),
                  ),
                ),

                // ────────────────────────────────────────────────
                // Security Section
                // ────────────────────────────────────────────────
                BlocBuilder<AccountBloc, AccountState>(
                  builder: (context, state) {
                    return SettingsSectionCard(
                      title: "Security",
                      child: SettingsToggleTile(
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedFingerprintScan,
                          color: isDark ? Colors.grey.shade400 : Colors.black,
                        ),
                        title: "App Lock",
                        subtitle:
                            "Enable biometric lock to keep your app secure.",
                        value: state.enabled,
                        onChanged: (value) {
                          if (value) {
                            context.read<AccountBloc>().add(EnableBiometric());
                          } else {
                            context.read<AccountBloc>().add(DisableBiometric());
                          }
                        },
                      ),
                    );
                  },
                ),

                // ────────────────────────────────────────────────
                // Language & Region Section
                // ────────────────────────────────────────────────
                BlocBuilder<AccountBloc, AccountState>(
                  builder: (context, state) {
                    return (state.error == null)
                        ? SettingsSectionCard(
                            title: "Language & Region",
                            child: Column(
                              children: [
                                SettingDropdownTile(
                                  icon: HugeIcons.strokeRoundedTranslate,
                                  title: 'Language',
                                  subtitle: 'Select your preferred language',
                                  value: state.selectedLanguage,
                                  items: state.languages,
                                  displayKey: 'name',
                                  isLoading: state.isLoading,
                                  onChanged: (val) {
                                    if (val == null) return;
                                    final selectedLang = state.languages
                                        .firstWhere(
                                          (lang) => lang['name'] == val,
                                          orElse: () => {},
                                        );
                                    final selectedCode = selectedLang.isNotEmpty
                                        ? selectedLang['code']
                                        : null;
                                    if (selectedCode != null) {
                                      context.read<AccountBloc>().add(
                                        UpdateLanguageEvent(selectedCode, val),
                                      );
                                    }
                                  },
                                ),

                                SettingDropdownTile(
                                  icon: HugeIcons.strokeRoundedDollar01,
                                  title: 'Currency',
                                  subtitle: 'Default currency for transactions',
                                  value: state.selectedCurrency,
                                  items: state.currencies,
                                  displayKey: 'full_name',
                                  isLoading: state.isLoading,
                                  onChanged: (val) {
                                    if (val != null) {
                                      context.read<AccountBloc>().add(
                                        UpdateCurrencyEvent(val),
                                      );
                                    }
                                  },
                                ),

                                SettingDropdownTile(
                                  icon: HugeIcons.strokeRoundedClock01,
                                  title: 'Timezone',
                                  subtitle: 'Your local timezone',
                                  value: state.selectedTimezone,
                                  items: state.timezones,
                                  displayKey: 'name',
                                  isLoading: state.isLoading,
                                  onChanged: (val) {
                                    if (val != null) {
                                      context.read<AccountBloc>().add(
                                        UpdateTimezoneEvent(val),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          )
                        : SizedBox.shrink();
                  },
                ),
                // ────────────────────────────────────────────────
                // Help & Support
                // ────────────────────────────────────────────────
                SettingsSectionCard(
                  title: "Help & Support",
                  child: Column(
                    children: [
                      SettingSectionTapTile(
                        icon: HugeIcons.strokeRoundedHelpCircle,
                        title: 'Odoo Help Center',
                        subtitle: 'Documentation, guides and resources',
                        onTap: () => urlLauncherUseCase.launch(
                          "https://www.odoo.com/documentation",
                        ),
                      ),
                      SettingSectionTapTile(
                        icon: HugeIcons.strokeRoundedCustomerSupport,
                        title: 'Odoo Support',
                        subtitle: 'Create a ticket with Odoo Support',
                        onTap: () => urlLauncherUseCase.launch(
                          "https://www.odoo.com/help",
                        ),
                      ),
                      SettingSectionTapTile(
                        icon: HugeIcons.strokeRoundedUserGroup,
                        title: 'Odoo Community Forum',
                        subtitle: 'Ask the community for help',
                        onTap: () => urlLauncherUseCase.launch(
                          "https://www.odoo.com/forum/help-1",
                        ),
                      ),
                    ],
                  ),
                ),

                // ────────────────────────────────────────────────
                // About Section (company info, social links)
                // ────────────────────────────────────────────────
                SettingsSectionCard(
                  title: "About",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SettingSectionTapTile(
                        icon: HugeIcons.strokeRoundedGlobe02,
                        title: 'Visit Website',
                        subtitle: 'www.cybrosys.com',
                        onTap: () => urlLauncherUseCase.launch(
                          "https://www.cybrosys.com",
                        ),
                      ),
                      SettingSectionTapTile(
                        icon: HugeIcons.strokeRoundedMail01,
                        title: 'Contact Us',
                        subtitle: 'info@cybrosys.com',
                        onTap: () => urlLauncherUseCase.launch(
                          "mailto:info@cybrosys.com",
                        ),
                      ),
                      SettingSectionTapTile(
                        icon: Icons.apps,
                        title: 'More Apps',
                        subtitle: 'View our other apps on Play Store',
                        onTap: () => urlLauncherUseCase.launch(
                          "https://play.google.com/store/apps/developer?id=Cybrosys",
                        ),
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Follow Us',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SettingSocialButton(
                            assetPath: 'assets/facebook.png',
                            underlineColor: const Color(0xFF1877F2),
                            onPressed: () async {
                              final success = await urlLauncherUseCase.launchSmart(
                                'https://www.facebook.com/cybrosystechnologies',
                              );

                              if (!success) {
                                _openInAppWebPage(
                                  Uri.parse(
                                    "https://www.facebook.com/cybrosystechnologies",
                                  ),
                                  title: "Facebook",
                                );
                              }
                            },
                          ),
                          SettingSocialButton(
                            assetPath: 'assets/linkedin.png',
                            underlineColor: const Color(0xFF0077B5),
                            onPressed: () async {
                              final success = await urlLauncherUseCase
                                  .launchSmart(
                                    'https://www.linkedin.com/company/cybrosys/',
                                  );

                              if (!success) {
                                _openInAppWebPage(
                                  Uri.parse(
                                    "https://www.linkedin.com/company/cybrosys/",
                                  ),
                                  title: "LinkedIn",
                                );
                              }
                            },
                          ),
                          SettingSocialButton(
                            assetPath: 'assets/instagram.png',
                            underlineColor: const Color(0xFFE4405F),
                            onPressed: () async {
                              final success = await urlLauncherUseCase
                                  .launchSmart(
                                    'https://www.instagram.com/cybrosystech/',
                                  );

                              if (!success) {
                                _openInAppWebPage(
                                  Uri.parse(
                                    "https://www.instagram.com/cybrosystech/",
                                  ),
                                  title: "Instagram",
                                );
                              }
                            },
                          ),
                          SettingSocialButton(
                            assetPath: 'assets/youtube.png',
                            underlineColor: const Color(0xFFFF0000),
                            onPressed: () async {
                              final success = await urlLauncherUseCase.launchSmart(
                                'https://www.youtube.com/channel/UCKjWLm7iCyOYINVspCSanjg',
                              );

                              if (!success) {
                                _openInAppWebPage(
                                  Uri.parse(
                                    "https://www.youtube.com/channel/UCKjWLm7iCyOYINVspCSanjg",
                                  ),
                                  title: "YouTube",
                                );
                              }
                            },
                          ),
                          const Divider(height: 32),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          '© ${DateTime.now().year} Cybrosys Technologies',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white : AppColors.primary,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
