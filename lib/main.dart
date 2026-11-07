import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'src/store.dart';
import 'src/app.dart';
import 'src/design.dart';

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
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'YIClass',
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        theme: expressiveTheme(Color(store.data['accent']), Brightness.light),
        darkTheme: expressiveTheme(
          Color(store.data['accent']),
          Brightness.dark,
        ),
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
