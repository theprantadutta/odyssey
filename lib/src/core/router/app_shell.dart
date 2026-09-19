import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../common/theme/odyssey_tokens.dart';
import '../../common/widgets/odyssey/nav_bar.dart';

/// The shell the four root destinations live inside.
///
/// Each branch keeps its own navigation stack, so pushing a trip detail from
/// Trips and then switching to Map and back returns to the detail rather than
/// to the list.
///
/// The nav floats over the content — [Scaffold.extendBody] lets the glass bar
/// blur what scrolls beneath it — so every screen here must reserve
/// [navScrollSpacer] at the foot of its scroll view.
///
/// Only the Home mock draws this bar; the Map and Settings mocks were drawn as
/// standalone screens. A persistent four-tab nav has to appear on all four
/// roots to be persistent at all, so it does.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onSelected(int index) {
    // Tapping the active tab pops that branch back to its root, which is the
    // conventional way out of a deep stack.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Scaffold(
      backgroundColor: t.canvas,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: OdysseyNavBar(
        destinations: kOdysseyDestinations,
        currentIndex: navigationShell.currentIndex,
        onSelected: _onSelected,
      ),
    );
  }
}
