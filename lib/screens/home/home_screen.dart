import 'package:flutter/material.dart';

import '../main/main_shell_screen.dart';

/// Backward compatibility wrapper.
/// The real home is now MainShellScreen (persistent bottom nav).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const MainShellScreen();
}