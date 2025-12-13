import 'package:flutter/material.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../data/models/achievement_model.dart';

class AchievementToast extends StatefulWidget {
  final AchievementUnlock achievement;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;

  const AchievementToast({
    super.key,
    required this.achievement,
    this.onDismiss,
    this.onTap,
  });

  @override
  State<AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends State<AchievementToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = AchievementTier.fromString(widget.achievement.tier);
    final tierColors = _getTierColors(tier);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space16,
                  vertical: AppSizes.space8,
                ),
                padding: const EdgeInsets.all(AppSizes.space16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tierColors[0],
                      tierColors[1],
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: tierColors[0].withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Icon container
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          widget.achievement.icon,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.space12),
                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.emoji_events,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Achievement Unlocked!',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.achievement.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+${widget.achievement.points} points',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Dismiss button
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.white.withOpacity(0.7),
                        size: 20,
                      ),
                      onPressed: () async {
                        await _controller.reverse();
                        widget.onDismiss?.call();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getTierColors(AchievementTier tier) {
    switch (tier) {
      case AchievementTier.bronze:
        return [const Color(0xFFCD7F32), const Color(0xFFE5A04F)];
      case AchievementTier.silver:
        return [const Color(0xFF9E9E9E), const Color(0xFFC0C0C0)];
      case AchievementTier.gold:
        return [const Color(0xFFFFAB00), const Color(0xFFFFD700)];
      case AchievementTier.platinum:
        return [const Color(0xFF00ACC1), const Color(0xFF00CED1)];
    }
  }
}

// Helper function to show achievement toast as overlay
void showAchievementToast(
  BuildContext context,
  AchievementUnlock achievement, {
  VoidCallback? onTap,
}) {
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 0,
      right: 0,
      child: AchievementToast(
        achievement: achievement,
        onDismiss: () => overlayEntry.remove(),
        onTap: () {
          overlayEntry.remove();
          onTap?.call();
        },
      ),
    ),
  );

  Overlay.of(context).insert(overlayEntry);

  // Auto dismiss after 5 seconds
  Future.delayed(const Duration(seconds: 5), () {
    if (overlayEntry.mounted) {
      overlayEntry.remove();
    }
  });
}

// Widget to show multiple achievement toasts
class AchievementToastQueue extends StatefulWidget {
  final List<AchievementUnlock> achievements;
  final VoidCallback? onAllDismissed;
  final void Function(AchievementUnlock)? onAchievementTap;

  const AchievementToastQueue({
    super.key,
    required this.achievements,
    this.onAllDismissed,
    this.onAchievementTap,
  });

  @override
  State<AchievementToastQueue> createState() => _AchievementToastQueueState();
}

class _AchievementToastQueueState extends State<AchievementToastQueue> {
  late List<AchievementUnlock> _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = List.from(widget.achievements);
  }

  void _dismissCurrent() {
    setState(() {
      if (_remaining.isNotEmpty) {
        _remaining.removeAt(0);
      }
      if (_remaining.isEmpty) {
        widget.onAllDismissed?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isEmpty) {
      return const SizedBox.shrink();
    }

    return AchievementToast(
      key: ValueKey(_remaining.first.achievementId),
      achievement: _remaining.first,
      onDismiss: _dismissCurrent,
      onTap: () {
        widget.onAchievementTap?.call(_remaining.first);
        _dismissCurrent();
      },
    );
  }
}
