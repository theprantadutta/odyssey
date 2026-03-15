import 'package:flutter/material.dart';
import '../../../../common/theme/app_colors.dart';
import '../../data/models/walkthrough_step_model.dart';

/// Builds the 5-step walkthrough for the Trip Detail screen.
class TripDetailWalkthroughSteps {
  TripDetailWalkthroughSteps._();

  static List<WalkthroughStep> build({
    required GlobalKey heroHeaderKey,
    required GlobalKey shareButtonKey,
    required GlobalKey moreOptionsKey,
    required GlobalKey tabBarKey,
    required GlobalKey tabContentKey,
  }) {
    return [
      WalkthroughStep(
        id: 'trip_detail_hero',
        targetKey: heroHeaderKey,
        title: 'Your Trip at a Glance',
        description:
            'See your trip dates, status, and cover photo. Scroll down to explore everything.',
        icon: Icons.panorama_rounded,
        accentColor: AppColors.sunnyYellow,
        preferredPosition: TooltipPosition.below,
        targetPadding: const EdgeInsets.all(4),
      ),
      WalkthroughStep(
        id: 'trip_detail_share',
        targetKey: shareButtonKey,
        title: 'Collaborate with Others',
        description:
            'Share this trip with friends or family. They can view or even help you plan!',
        icon: Icons.share_outlined,
        accentColor: AppColors.oceanTeal,
        preferredPosition: TooltipPosition.below,
      ),
      WalkthroughStep(
        id: 'trip_detail_more',
        targetKey: moreOptionsKey,
        title: 'Trip Actions',
        description:
            'Edit your trip, save it as a template, manage sharing, or delete it from here.',
        icon: Icons.more_vert_rounded,
        accentColor: AppColors.lavenderDream,
        preferredPosition: TooltipPosition.below,
      ),
      WalkthroughStep(
        id: 'trip_detail_tabs',
        targetKey: tabBarKey,
        title: 'Everything in Tabs',
        description:
            'Swipe or tap to switch between Overview, Activities, Packing, Budget, Documents, Memories, and Map.',
        icon: Icons.tab_rounded,
        accentColor: AppColors.coralBurst,
        preferredPosition: TooltipPosition.below,
        targetPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),
      WalkthroughStep(
        id: 'trip_detail_content',
        targetKey: tabContentKey,
        title: 'Dive Into the Details',
        description:
            'Each tab lets you add and manage different aspects of your trip. Start with Activities to build your itinerary!',
        icon: Icons.touch_app_rounded,
        accentColor: AppColors.skyBlue,
        preferredPosition: TooltipPosition.above,
        targetPadding: const EdgeInsets.all(4),
      ),
    ];
  }
}
