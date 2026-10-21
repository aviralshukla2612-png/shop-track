import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'core/theme/app_theme.dart';
import 'database/database_seeder.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/catalogue/catalogue_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/expenses/expenses_screen.dart';
import 'features/inventory/inventory_screen.dart';
import 'features/purchases/purchase_list_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/settings/settings_screen.dart';
import 'providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    await DatabaseSeeder.seedIfEmpty();
  } catch (e) {
    debugPrint('Database initialization warning: $e');
  }

  runApp(
    const ProviderScope(
      child: BusinessTrackerApp(),
    ),
  );
}

class BusinessTrackerApp extends StatelessWidget {
  const BusinessTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shop Track',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppStartupGate(),
    );
  }
}

class AppStartupGate extends ConsumerStatefulWidget {
  const AppStartupGate({super.key});

  @override
  ConsumerState<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends ConsumerState<AppStartupGate> {
  bool _isLoading = true;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final repo = ref.read(settingsRepoProvider);
    final onboarded = await repo.isOnboarded();
    if (mounted) {
      setState(() {
        _needsOnboarding = !onboarded;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (_needsOnboarding) {
      return OnboardingScreen(
        onCompleted: () {
          setState(() {
            _needsOnboarding = false;
          });
        },
      );
    }

    return const MainNavigationShell();
  }
}


class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    DatabaseSeeder.seedIfEmpty();
    if (kIsWeb) {
      final tabParam = Uri.base.queryParameters['tab'];
      if (tabParam != null) {
        final parsed = int.tryParse(tabParam);
        if (parsed != null && parsed >= 0 && parsed <= 7) {
          _currentIndex = parsed;
        }
      }
    }
  }

  void _onNavigate(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardScreen(onNavigate: _onNavigate),
      const CatalogueScreen(),
      const InventoryScreen(),
      PurchaseListScreen(onBrowseCatalogue: () => _onNavigate(1)),
      const AnalyticsScreen(),
      const ReportsScreen(),
      const ExpensesScreen(),
      const SettingsScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: _currentIndex,
                        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
                        labelType: NavigationRailLabelType.all,
                        leading: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.storefront, color: Colors.white, size: 26),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('Shop Track', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                            ],
                          ),
                        ),
                        destinations: const [
                          NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
                          NavigationRailDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: Text('Catalogue')),
                          NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Inventory')),
                          NavigationRailDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: Text('Purchase List')),
                          NavigationRailDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: Text('Analytics')),
                          NavigationRailDestination(icon: Icon(Icons.picture_as_pdf_outlined), selectedIcon: Icon(Icons.picture_as_pdf), label: Text('Reports')),
                          NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Expenses')),
                          NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
                        ],
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: screens[_currentIndex]),
              ],
            ),
          );
        }

        // Mobile layout with NavigationBar
        return Scaffold(
          body: screens[_currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex > 4 ? 4 : _currentIndex,
            onDestinationSelected: (idx) {
              if (idx == 4) {
                // Show more options menu for mobile
                _showMoreOptionsSheet(context);
              } else {
                setState(() => _currentIndex = idx);
              }
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
              NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Catalogue'),
              NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventory'),
              NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Purchases'),
              NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
            ],
          ),
        );
      },
    );
  }

  void _showMoreOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.analytics_outlined, color: AppTheme.accentColor),
                title: const Text('Financial Analytics & COGS Profit'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 4);
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                title: const Text('PDF Reports & Export'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 5);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: Colors.orange),
                title: const Text('Operating Expenses'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 6);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: Colors.blueGrey),
                title: const Text('Settings & Catalogue Provenance'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 7);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
