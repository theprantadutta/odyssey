import 'package:flutter/material.dart';

import '../../../../common/theme/app_colors.dart';
import '../../data/models/achievement_model.dart';

/// Maps the backend's semantic icon names onto this app's icon set.
///
/// The server stores a name like "receipt" rather than a glyph, so each client picks
/// an icon that belongs in its own design language. Without this the raw name ends up
/// rendered as text.
IconData achievementIcon(String name) => switch (name) {
      // Trips
      'airplane-takeoff' => Icons.flight_takeoff_rounded,
      'suitcase' => Icons.work_rounded,
      'globe' => Icons.public_rounded,
      'compass' => Icons.explore_rounded,
      'crown' => Icons.workspace_premium_rounded,
      // Memories
      'camera' => Icons.photo_camera_rounded,
      'photo-album' => Icons.photo_library_rounded,
      'images' => Icons.collections_rounded,
      // Activities
      'calendar-check' => Icons.event_available_rounded,
      'list-checks' => Icons.checklist_rounded,
      'calendar-star' => Icons.auto_awesome_rounded,
      // Budget
      'receipt' => Icons.receipt_long_rounded,
      'wallet' => Icons.account_balance_wallet_rounded,
      'piggy-bank' => Icons.savings_rounded,
      // Packing
      'bag' => Icons.backpack_rounded,
      'luggage' => Icons.luggage_rounded,
      // Special
      'calendar-week' => Icons.date_range_rounded,
      'calendar-month' => Icons.calendar_month_rounded,
      'coins' => Icons.currency_exchange_rounded,
      'sunrise' => Icons.wb_twilight_rounded,
      'lightning' => Icons.bolt_rounded,
      'utensils' => Icons.restaurant_rounded,
      'binoculars' => Icons.travel_explore_rounded,
      'world' => Icons.language_rounded,
      // A new achievement seeded server-side should still render as something.
      _ => Icons.emoji_events_rounded,
    };

/// The accent colour for a tier.
///
/// Odyssey's palette rather than literal metals: bronze and silver rendered as brown
/// and grey clash with every other surface in the app, and a grey "earned" badge is
/// indistinguishable from a locked one.
Color tierColor(AchievementTier tier) => switch (tier) {
      AchievementTier.bronze => AppColors.coralBurst,
      AchievementTier.silver => AppColors.skyBlue,
      AchievementTier.gold => AppColors.sunnyYellow,
      AchievementTier.platinum => AppColors.lavenderDream,
    };
