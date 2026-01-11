import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';
import '../animations/animation_constants.dart';
import '../../core/services/location_service.dart';

/// A button that fetches the current GPS location and populates lat/lng controllers
class LocationPickerButton extends StatefulWidget {
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final VoidCallback? onLocationFetched;
  final bool isEnabled;

  const LocationPickerButton({
    super.key,
    required this.latitudeController,
    required this.longitudeController,
    this.onLocationFetched,
    this.isEnabled = true,
  });

  @override
  State<LocationPickerButton> createState() => _LocationPickerButtonState();
}

class _LocationPickerButtonState extends State<LocationPickerButton>
    with SingleTickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  bool _isLoading = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AppAnimations.micro,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: AppAnimations.buttonPress,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.isEnabled && !_isLoading) {
      _scaleController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails _) => _scaleController.reverse();
  void _handleTapCancel() => _scaleController.reverse();

  Future<void> _getLocation() async {
    if (_isLoading || !widget.isEnabled) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final result = await _locationService.getCurrentLocation();

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.isSuccess) {
      // Success - populate the controllers
      widget.latitudeController.text = result.latitude!.toStringAsFixed(6);
      widget.longitudeController.text = result.longitude!.toStringAsFixed(6);
      HapticFeedback.heavyImpact();

      // Show success feedback
      _showSnackBar(
        message: 'Location captured successfully',
        isError: false,
      );

      widget.onLocationFetched?.call();
    } else {
      // Error - show appropriate message
      final error = result.error!;
      _showSnackBar(
        message: error.message,
        isError: true,
        showSettingsAction: error.canOpenSettings,
        onSettingsPressed: () async {
          if (error == LocationError.serviceDisabled) {
            await _locationService.openLocationSettings();
          } else {
            await _locationService.openAppSettings();
          }
        },
      );
    }
  }

  void _showSnackBar({
    required String message,
    required bool isError,
    bool showSettingsAction = false,
    VoidCallback? onSettingsPressed,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: AppSizes.iconSm,
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySmall.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        margin: const EdgeInsets.all(AppSizes.space16),
        action: showSettingsAction
            ? SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: onSettingsPressed ?? () {},
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = !widget.isEnabled || _isLoading;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _getLocation,
      child: AnimatedBuilder(
        animation: _scaleController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space16,
                vertical: AppSizes.space12,
              ),
              decoration: BoxDecoration(
                color: isDisabled
                    ? AppColors.warmGray
                    : AppColors.lemonLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(
                  color: isDisabled
                      ? AppColors.mutedGray.withValues(alpha: 0.3)
                      : AppColors.sunnyYellow.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    SizedBox(
                      width: AppSizes.iconSm,
                      height: AppSizes.iconSm,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.goldenGlow,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.my_location_rounded,
                      size: AppSizes.iconSm,
                      color: isDisabled
                          ? AppColors.mutedGray
                          : AppColors.goldenGlow,
                    ),
                  const SizedBox(width: AppSizes.space8),
                  Text(
                    _isLoading ? 'Getting Location...' : 'Get Current Location',
                    style: AppTypography.labelMedium.copyWith(
                      color: isDisabled
                          ? AppColors.mutedGray
                          : AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
