import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:misgastos/providers/gastos_provider.dart';
import 'package:misgastos/screens/parametricas/pantalla_configuracion.dart';
import 'package:misgastos/screens/gastos/pantalla_gastos.dart';
import 'package:misgastos/screens/dashboard/pantalla_dashboard.dart';
import 'package:misgastos/screens/grupos/pantalla_grupos_resumen.dart';
import 'package:misgastos/screens/gastos/pantalla_facturacion.dart';
import 'package:misgastos/utils/formato.dart';
import 'package:misgastos/utils/iconos.dart';
import 'package:misgastos/models/periodo.dart';
import 'package:misgastos/screens/shared/selector_periodo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);

  runApp(
    ChangeNotifierProvider(
      create: (_) => GastosProvider()..inicializar(),
      child: const GastosApp(),
    ),
  );
}

class GastosApp extends StatelessWidget {
  const GastosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mis Gastos',
      debugShowCheckedModeBanner: false,
      // Azul celeste — se adapta al sistema del celular
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0288D1), // Azul celeste primario
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // Tipografía más limpia
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          titleMedium: TextStyle(fontWeight: FontWeight.w700),
          labelLarge: TextStyle(fontWeight: FontWeight.w600),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Color(0xFFE3F2FD)), // azul muy suave
          ),
        ),
        // AppBar limpio
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF01579B),
          titleTextStyle: TextStyle(
            color: Color(0xFF01579B),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        // NavigationBar
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE3F2FD),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
        // Botones
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0288D1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        // Inputs
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB3E5FC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB3E5FC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0288D1), width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFFF8FBFF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F9FF),
      ),

      // Tema oscuro — azul marino
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF29B6F6), // Azul más claro en dark
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          titleMedium: TextStyle(fontWeight: FontWeight.w700),
          labelLarge: TextStyle(fontWeight: FontWeight.w600),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: Color(0xFF0D1B2A),
          foregroundColor: Color(0xFF29B6F6),
          titleTextStyle: TextStyle(
            color: Color(0xFF29B6F6),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0D1B2A),
          indicatorColor: const Color(0xFF0288D1).withOpacity(0.3),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF29B6F6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF29B6F6), width: 2),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A1628),
      ),

      // Se adapta automáticamente al sistema
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      home: const PantallaRaiz(),
    );
  }
}

class PantallaRaiz extends StatefulWidget {
  const PantallaRaiz({super.key});

  @override
  State<PantallaRaiz> createState() => _PantallaRaizState();
}

class _PantallaRaizState extends State<PantallaRaiz> {
  int _tabActual = 0;

  final List<_TabInfo> _tabs = const [
    _TabInfo(
      label: 'Gastos',
      icono: Icons.receipt_long_outlined,
      iconoActivo: Icons.receipt_long,
    ),
    _TabInfo(
      label: 'Facturación',
      icono: Icons.credit_card_outlined,
      iconoActivo: Icons.credit_card,
    ),
    _TabInfo(
      label: 'Dashboard',
      icono: Icons.home_outlined,
      iconoActivo: Icons.home,
    ),
    _TabInfo(
      label: 'Grupos',
      icono: Icons.group_outlined,
      iconoActivo: Icons.group,
    ),
    _TabInfo(
      label: 'Config',
      icono: Icons.settings_outlined,
      iconoActivo: Icons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GastosProvider>();

    final List<Widget> pantallas = [
      const PantallaGastos(),
      const PantallaFacturacion(),
      const PantallaDashboard(),
      const PantallaGruposResumen(),
      const PantallaConfiguracion(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _tabActual,
        children: pantallas,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabActual,
        onDestinationSelected: (i) => setState(() => _tabActual = i),
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icono),
                  selectedIcon: Icon(t.iconoActivo),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _PantallaProxima extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;

  const _PantallaProxima({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(titulo), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 72, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text(titulo,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitulo,
                style: TextStyle(color: cs.outline)),
          ],
        ),
      ),
    );
  }
}

class _TabInfo {
  final String label;
  final IconData icono;
  final IconData iconoActivo;
  const _TabInfo(
      {required this.label,
      required this.icono,
      required this.iconoActivo});
}
