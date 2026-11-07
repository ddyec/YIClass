import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'src/store.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = await Store.open();
    runApp(YIClassApp(store: store));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText('无法打开本地资料，请保留应用数据并重试。\n$e'),
            ),
          ),
        ),
      ),
    );
  }
}

class YIClassApp extends StatelessWidget {
  const YIClassApp({super.key, required this.store});
  final Store store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      ThemeData theme(Brightness brightness) {
        final colors = ColorScheme.fromSeed(
          seedColor: Color(store.data['accent']),
          brightness: brightness,
        );
        return ThemeData(
          useMaterial3: true,
          fontFamily: 'NotoSansSC',
          colorScheme: colors,
          scaffoldBackgroundColor: brightness == Brightness.light
              ? const Color(0xfff6f7fb)
              : const Color(0xff11141b),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            scrolledUnderElevation: 0,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 5),
            color: brightness == Brightness.light
                ? Colors.white
                : const Color(0xff1d222c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          listTileTheme: const ListTileThemeData(
            contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          ),
        );
      }

      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'YIClass',
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        themeMode: switch (store.data['theme']) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        home: Home(store: store),
      );
    },
  );
}
