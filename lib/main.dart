import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:lizaplayer/l10n/app_localizations.dart';
import 'package:lizaplayer/screens/auth_screen.dart';
import 'package:lizaplayer/screens/home_screen.dart';
import 'package:lizaplayer/services/token_storage.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
final accentColorProvider = StateProvider<Color>((ref) => Colors.cyanAccent);
final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));
final glassEnabledProvider = StateProvider<bool>((ref) => false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final savedTheme = await TokenStorage.getThemeMode();
  final savedColorValue = await TokenStorage.getAccentColor();
  final savedLang = await TokenStorage.getLanguage();
  final savedGlassEnabled = await TokenStorage.getGlassEnabled() ?? false;

  final initialLocale = savedLang == 'ru' ? const Locale('ru') : const Locale('en');

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1280, 820),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.normal,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setTitle('lizaplayer');
  });

  runApp(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith((ref) => savedTheme),
      accentColorProvider.overrideWith((ref) => Color(savedColorValue)),
      localeProvider.overrideWith((ref) => initialLocale),
      glassEnabledProvider.overrideWith((ref) => savedGlassEnabled),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accentColor = ref.watch(accentColorProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'lizaplayer',
      debugShowCheckedModeBanner: false,

      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ru')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.light(primary: accentColor),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.dark(primary: accentColor),
      ),
      themeMode: themeMode,

      home: const InitialScreen(),
    );
  }
}

class InitialScreen extends ConsumerWidget {
  const InitialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: TokenStorage.getToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final token = snapshot.data;
        return token == null || token.isEmpty
            ? const AuthScreen()
            : HomeScreen(token: token);
      },
    );
  }
}
