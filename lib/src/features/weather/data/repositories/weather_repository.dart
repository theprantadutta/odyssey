import 'package:odyssey/src/core/network/dio_client.dart';
import 'package:odyssey/src/features/weather/data/models/weather_model.dart';

class WeatherRepository {
  final DioClient _dioClient = DioClient();

  /// Get current weather for a location
  Future<WeatherData> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _dioClient.get(
      '/weather/current',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    return WeatherData.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get weather forecast for a location
  Future<WeatherForecastResponse> getForecast({
    required double latitude,
    required double longitude,
    int days = 5,
  }) async {
    final response = await _dioClient.get(
      '/weather/forecast',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'days': days,
      },
    );
    return WeatherForecastResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  /// Get weather forecast for a trip
  Future<TripWeatherResponse> getTripWeather({
    required String tripId,
    required double latitude,
    required double longitude,
    required String startDate,
    required String endDate,
  }) async {
    final response = await _dioClient.get(
      '/weather/trip/$tripId',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'start_date': startDate,
        'end_date': endDate,
      },
    );
    return TripWeatherResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
