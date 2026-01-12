import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/glass_container.dart';
import '../../../../common/widgets/custom_button.dart';
import '../../../../common/widgets/section_divider.dart';
import '../../data/models/trip_model.dart';

class TripOverviewTab extends StatelessWidget {
  final TripModel trip;
  final int duration;

  const TripOverviewTab({
    super.key,
    required this.trip,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Swipe hint
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space12,
                vertical: AppSizes.space8,
              ),
              decoration: BoxDecoration(
                color: AppColors.oceanTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swipe,
                    size: 16,
                    color: AppColors.oceanTeal,
                  ),
                  const SizedBox(width: AppSizes.space8),
                  Text(
                    'Swipe left or right to explore more sections',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.oceanTeal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.space16),

          // Trip Stats
          _buildStatsRow(),

          // Divider after stats
          const SectionDivider(
            padding: EdgeInsets.symmetric(vertical: AppSizes.space20),
          ),

          // Description Section
          if (trip.description != null && trip.description!.isNotEmpty) ...[
            Text(
              'About This Trip',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: AppSizes.space12),
            GlassContainer(
              child: Text(
                trip.description!,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
            const SectionDivider(
              padding: EdgeInsets.symmetric(vertical: AppSizes.space20),
            ),
          ],

          // Tags Section
          if (trip.tags != null && trip.tags!.isNotEmpty) ...[
            Text(
              'Tags',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: AppSizes.space12),
            Wrap(
              spacing: AppSizes.space8,
              runSpacing: AppSizes.space8,
              children: trip.tags!.map((tag) {
                return CustomChip(
                  label: tag,
                  icon: Icons.label,
                );
              }).toList(),
            ),
            const SectionDivider(
              padding: EdgeInsets.symmetric(vertical: AppSizes.space20),
            ),
          ],

          // Dates Section
          Text(
            'Trip Timeline',
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: AppSizes.space12),
          GlassContainer(
            child: Column(
              children: [
                _buildDateRow(
                  icon: Icons.flight_takeoff,
                  label: 'Departure',
                  date: DateTime.parse(trip.startDate),
                ),
                const Divider(height: AppSizes.space24),
                _buildDateRow(
                  icon: Icons.flight_land,
                  label: 'Return',
                  date: DateTime.parse(trip.endDate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.calendar_month,
            value: '$duration',
            label: duration == 1 ? 'Day' : 'Days',
            color: AppColors.sunsetGold,
          ),
        ),
        const SizedBox(width: AppSizes.space12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.location_on,
            value: '0',
            label: 'Activities',
            color: AppColors.coralPink,
          ),
        ),
        const SizedBox(width: AppSizes.space12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.photo_camera,
            value: '0',
            label: 'Memories',
            color: AppColors.mintGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return GlassContainer(
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: AppSizes.iconLg,
          ),
          const SizedBox(height: AppSizes.space8),
          Text(
            value,
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.charcoal,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow({
    required IconData icon,
    required String label,
    required DateTime date,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSizes.space12),
          decoration: BoxDecoration(
            color: AppColors.lemonLight,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Icon(
            icon,
            color: AppColors.goldenGlow,
            size: AppSizes.iconMd,
          ),
        ),
        const SizedBox(width: AppSizes.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.space4),
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(date),
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
