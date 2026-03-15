import 'package:flutter/material.dart';

/// Position preference for the tooltip relative to the target widget
enum TooltipPosition { above, below }

/// Represents a single step in a walkthrough segment
class WalkthroughStep {
  /// Unique identifier for this step (e.g. 'dashboard_header')
  final String id;

  /// GlobalKey attached to the target widget to highlight
  final GlobalKey targetKey;

  /// Tooltip title (displayed in Nunito headline style)
  final String title;

  /// Tooltip description (displayed in Inter body style)
  final String description;

  /// Icon displayed in the tooltip's colored circle
  final IconData icon;

  /// Accent color for the glow, icon circle, etc.
  final Color accentColor;

  /// Preferred tooltip position relative to the target
  final TooltipPosition preferredPosition;

  /// Extra padding around the spotlight cutout
  final EdgeInsets targetPadding;

  const WalkthroughStep({
    required this.id,
    required this.targetKey,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.preferredPosition = TooltipPosition.below,
    this.targetPadding = const EdgeInsets.all(8),
  });
}
