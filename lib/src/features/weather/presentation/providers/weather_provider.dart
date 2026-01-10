import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:odyssey/src/features/weather/data/models/weather_model.dart';
import 'package:odyssey/src/features/weather/data/repositories/weather_repository.dart';

part 'weather_provider.g.dart';

/// Weather repository provider
@Riverpod(keepAlive: true)
WeatherRepository weatherRepository(Ref ref) {
  return WeatherRepository();
}

/// Current weather for a location
@Riverpod(keepAlive: true)
class CurrentWeather extends _$CurrentWeather {
  @override
  Future<WeatherData?> build(double latitude, double longitude) async {
    try {
      final repository = ref.read(weatherRepositoryProvider);
      return await repository.getCurrentWeather(
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(weatherRepositoryProvider);
      return repository.getCurrentWeather(
        latitude: latitude,
        longitude: longitude,
      );
    });
  }

  @override
  double get latitude => arg1;
  @override
  double get longitude => arg2;

  double get arg1 => throw UnimplementedError();
  double get arg2 => throw UnimplementedError();
}

/// Weather forecast for a location
@Riverpod(keepAlive: true)
class WeatherForecast extends _$WeatherForecast {
  @override
  Future<WeatherForecastResponse?> build(
    double latitude,
    double longitude, {
    int days = 5,
  }) async {
    try {
      final repository = ref.read(weatherRepositoryProvider);
      return await repository.getForecast(
        latitude: latitude,
        longitude: longitude,
        days: days,
      );
    } catch (e) {
      return null;
    }
  }
}

/// Trip weather with packing suggestions
@Riverpod(keepAlive: true)
class TripWeather extends _$TripWeather {
  @override
  Future<TripWeatherResponse?> build(
    String tripId, {
    required double latitude,
    required double longitude,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final repository = ref.read(weatherRepositoryProvider);
      return await repository.getTripWeather(
        tripId: tripId,
        latitude: latitude,
        longitude: longitude,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      return null;
    }
  }
}
