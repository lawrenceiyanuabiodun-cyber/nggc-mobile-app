import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_dashboard_screen.dart';
import '../bible/bible_language_screen.dart';
import '../manuals/manuals_screen.dart';
import '../profile/profile_screen.dart';
import 'home_tab_screen.dart';

/// ─────────────────────────────────────────────────────
/// MainShellScreen
/// Persistent bottom nav shell for all main tabs.
/// Uses IndexedStack so all tabs stay mounted and
/// switching between them is instant + state-preserving.
///
/// Back button on any tab (other than Home) returns to Home tab.
/// Back button on Home tab exits the app.
/// ─────────────────────────────────────────────────────
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build the list of tab screens dynamically
    final tabs = <Widget>[
      const HomeTabScreen(),
      const BibleLanguageScreen(),
      const ManualsScreen(),
      const ProfileScreen(),
      if (isAdmin) const AdminDashboardScreen(),
    ];

    final navItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.menu_book_outlined),
        activeIcon: Icon(Icons.menu_book),
        label: 'Bible',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.import_contacts_outlined),
        activeIcon: Icon(Icons.import_contacts),
        label: 'Manuals',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Profile',
      ),
      if (isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          activeIcon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
    ];

    // Safety: if user was admin then logged out, clamp the index
    final safeIndex = _currentIndex.clamp(0, tabs.length - 1);

    return WillPopScope(
      onWillPop: () async {
        // If not on Home tab, back goes to Home
        if (safeIndex != 0) {
          setState(() => _currentIndex = 0);
          return false; // don't exit
        }
        return true; // on Home tab -> allow exit
      },
      child: Scaffold(
        body: IndexedStack(
          index: safeIndex,
          children: tabs,
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor:
              isDark ? const Color(0xFF12122A) : Colors.white,
          currentIndex: safeIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          selectedItemColor:
              isDark ? AppTheme.accentGold : AppTheme.primaryBlue,
          unselectedItemColor:
              isDark ? Colors.white38 : AppTheme.textHint,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 10,
          items: navItems,
        ),
      ),
    );
  }
}