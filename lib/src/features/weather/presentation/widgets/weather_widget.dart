import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:odyssey/src/common/theme/app_colors.dart';
import 'package:odyssey/src/common/theme/app_sizes.dart';
import 'package:odyssey/src/features/weather/data/models/weather_model.dart';

class WeatherWidget extends StatelessWidget {
  final TripWeatherResponse? weatherData;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRefresh;

  const WeatherWidget({
    super.key,
    this.weatherData,
    this.isLoading = false,
    this.error,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return _buildLoadingState();
    }

    if (error != null) {
      return _buildErrorState(theme);
    }

    if (weatherData == null || weatherData!.forecast.isEmpty) {
      return _buildEmptyState(theme);
    }

    return _buildWeatherContent(theme);
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.space16),
      decoration: BoxDecoration(
        color: AppColors.skyBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: AppColors.skyBlue),
          SizedBox(height: AppSizes.space12),
          Text('Loading weather forecast...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.space16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.warning),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: Text(
              'Weather unavailable',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.warning),
              onPressed: onRefresh,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.space16),
      decoration: BoxDecoration(
        color: AppColors.warmGray,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Row(
        children: [
          const Icon(Icons.wb_sunny_outlined, color: AppColors.textSecondary),
          const SizedBox(width: AppSizes.space12),
          Text(
            'No weather data available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherContent(ThemeData theme) {
    final forecast = weatherData!.forecast;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.skyBlue.withValues(alpha: 0.15),
            AppColors.oceanTeal.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSizes.space16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.space8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: const Icon(
                    Icons.wb_sunny,
                    color: AppColors.goldenGlow,
                  ),
                ),
                const SizedBox(width: AppSizes.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weather Forecast',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        weatherData!.locationName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: onRefresh,
                    color: AppColors.oceanTeal,
                  ),
              ],
            ),
          ),

          // Forecast days - horizontal scroll
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSizes.space12),
              itemCount: forecast.length,
              itemBuilder: (context, index) {
                final item = forecast[index];
                return _ForecastDayCard(forecast: item);
              },
            ),
          ),

          // Packing suggestions
          if (weatherData!.packingSuggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSizes.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        size: 18,
                        color: AppColors.goldenGlow,
                      ),
                      const SizedBox(width: AppSizes.space8),
                      Text(
                        'Packing Tips',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.space8),
                  Wrap(
                    spacing: AppSizes.space8,
                    runSpacing: AppSizes.space8,
                    children: weatherData!.packingSuggestions.map((tip) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.space12,
                          vertical: AppSizes.space4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusFull),
                        ),
                        child: Text(
                          tip,
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ForecastDayCard extends StatelessWidget {
  final WeatherForecastItem forecast;

  const _ForecastDayCard({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final condition = forecast.primaryCondition;
    final dayName = DateFormat('EEE').format(forecast.date);
    final dateStr = DateFormat('d/M').format(forecast.date);

    return Container(
      width: 80,
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.space4),
      padding: const EdgeInsets.all(AppSizes.space8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dayName,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            dateStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: AppSizes.space8),
          Text(
            condition?.emoji ?? '🌤️',
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(height: AppSizes.space8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${forecast.tempMax.round()}°',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '/${forecast.tempMin.round()}°',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (forecast.rainProbability != null && forecast.rainProbability! > 20)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.water_drop, size: 10, color: AppColors.skyBlue),
                Text(
                  ' ${forecast.rainProbability!.round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppColors.skyBlue,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Compact weather widget for trip card
class WeatherBadge extends StatelessWidget {
  final WeatherForecastItem? forecast;

  const WeatherBadge({super.key, this.forecast});

  @override
  Widget build(BuildContext context) {
    if (forecast == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space8,
        vertical: AppSizes.space4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            forecast!.primaryCondition?.emoji ?? '🌤️',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            '${forecast!.tempMax.round()}°',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
