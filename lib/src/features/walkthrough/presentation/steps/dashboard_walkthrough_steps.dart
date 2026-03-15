import 'package:flutter/material.dart';
import '../../../../common/theme/app_colors.dart';
import '../../data/models/walkthrough_step_model.dart';

/// Builds the 6-step walkthrough for the Dashboard screen.
class DashboardWalkthroughSteps {
  DashboardWalkthroughSteps._();

  static List<WalkthroughStep> build({
    required GlobalKey headerKey,
    required GlobalKey notificationKey,
    required GlobalKey moreMenuKey,
    required GlobalKey searchBarKey,
    required GlobalKey quickFiltersKey,
    required GlobalKey fabKey,
  }) {
    return [
      WalkthroughStep(
        id: 'dashboard_header',
        targetKey: headerKey,
        title: 'Welcome to Your Dashboard',
        description:
            'This is your home base. All your trips live here, and you can always return here.',
        icon: Icons.travel_explore,
        accentColor: AppColors.sunnyYellow,
        preferredPosition: TooltipPosition.below,
      ),
      WalkthroughStep(
        id: 'dashboard_notification',
        targetKey: notificationKey,
        title: 'Stay in the Loop',
        description:
            'Tap the bell for trip invites, collaboration updates, and reminders.',
        icon: Icons.notifications_outlined,
        accentColor: AppColors.skyBlue,
        preferredPosition: TooltipPosition.below,
      ),
      WalkthroughStep(
        id: 'dashboard_more_menu',
        targetKey: moreMenuKey,
        title: 'Explore More Features',
        description:
            'Find Templates, Shared Trips, Achievements, Statistics, and Settings here.',
        icon: Icons.more_vert_rounded,
        accentColor: AppColors.lavenderDream,
        preferredPosition: TooltipPosition.below,
      ),
      WalkthroughStep(
        id: 'dashboard_search',
        targetKey: searchBarKey,
        title: 'Find Trips Fast',
        description:
            'Search by name or tap the filter icon to sort by status, date, or tags.',
        icon: Icons.search_rounded,
        accentColor: AppColors.oceanTeal,
        preferredPosition: TooltipPosition.below,
      ),
      WalkthroughStep(
        id: 'dashboard_quick_filters',
        targetKey: quickFiltersKey,
        title: 'Filter at a Glance',
        description:
            'Quickly switch between Planned, Ongoing, and Completed trips.',
        icon: Icons.filter_list_rounded,
        accentColor: AppColors.coralBurst,
        preferredPosition: TooltipPosition.below,
      ),
      WalkthroughStep(
        id: 'dashboard_fab',
        targetKey: fabKey,
        title: 'Start a New Adventure',
        description:
            'Ready to plan? Tap here to create a new trip with activities, packing lists, budgets, and more!',
        icon: Icons.add_rounded,
        accentColor: AppColors.sunnyYellow,
        preferredPosition: TooltipPosition.above,
      ),
    ];
  }
}
