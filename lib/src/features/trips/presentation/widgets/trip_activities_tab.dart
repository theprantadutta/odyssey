import 'package:flutter/material.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/widgets/empty_state.dart';

class TripActivitiesTab extends StatelessWidget {
  final String tripId;

  const TripActivitiesTab({
    super.key,
    required this.tripId,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Fetch and display activities for this trip
    return EmptyState(
      icon: Icons.explore,
      title: 'No Activities Yet',
      message: 'Start planning your trip by adding activities and places to visit.',
      actionLabel: 'Add Activity',
      onAction: () {
        // TODO: Navigate to add activity screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add activity feature coming soon!'),
            backgroundColor: AppColors.info,
          ),
        );
      },
    );
  }
}
