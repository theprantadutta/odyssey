import 'package:flutter/material.dart';
import '../../../../common/theme/app_colors.dart';
import '../../data/models/walkthrough_step_model.dart';

/// Builds the 4-step walkthrough for the Trip Creation form.
class TripCreationWalkthroughSteps {
  TripCreationWalkthroughSteps._();

  static List<WalkthroughStep> build({
    required GlobalKey basicInfoKey,
    required GlobalKey coverImageKey,
    required GlobalKey datesKey,
    required GlobalKey budgetKey,
  }) {
    return [
      WalkthroughStep(
        id: 'trip_creation_basic_info',
        targetKey: basicInfoKey,
        title: 'Name Your Adventure',
        description:
            'Give your trip a title and optional description. Make it memorable!',
        icon: Icons.title_rounded,
        accentColor: AppColors.sunnyYellow,
        preferredPosition: TooltipPosition.below,
        targetPadding: const EdgeInsets.all(4),
      ),
      WalkthroughStep(
        id: 'trip_creation_cover_image',
        targetKey: coverImageKey,
        title: 'Add a Cover Photo',
        description:
            'Pick a photo to make your trip card stand out on the dashboard.',
        icon: Icons.image_rounded,
        accentColor: AppColors.coralBurst,
        preferredPosition: TooltipPosition.below,
        targetPadding: const EdgeInsets.all(4),
      ),
      WalkthroughStep(
        id: 'trip_creation_dates',
        targetKey: datesKey,
        title: 'Set Your Travel Dates',
        description:
            'Pick start and end dates. These help track your trip status automatically.',
        icon: Icons.calendar_today_rounded,
        accentColor: AppColors.skyBlue,
        preferredPosition: TooltipPosition.below,
        targetPadding: const EdgeInsets.all(4),
      ),
      WalkthroughStep(
        id: 'trip_creation_budget',
        targetKey: budgetKey,
        title: 'Plan Your Budget',
        description:
            'Set a budget in any currency. All expenses you add later will be tracked against this.',
        icon: Icons.account_balance_wallet_rounded,
        accentColor: AppColors.oceanTeal,
        preferredPosition: TooltipPosition.above,
        targetPadding: const EdgeInsets.all(4),
      ),
    ];
  }
}
