import 'package:flutter/material.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/widgets/empty_state.dart';

class TripMemoriesTab extends StatelessWidget {
  final String tripId;

  const TripMemoriesTab({
    super.key,
    required this.tripId,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Fetch and display memories/photos for this trip
    return EmptyState(
      icon: Icons.photo_library,
      title: 'No Memories Yet',
      message: 'Capture and preserve your favorite moments from this trip.',
      actionLabel: 'Add Memory',
      onAction: () {
        // TODO: Navigate to add memory screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add memory feature coming soon!'),
            backgroundColor: AppColors.info,
          ),
        );
      },
    );
  }
}
