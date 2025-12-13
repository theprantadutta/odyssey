/// Weather condition details
class WeatherCondition {
  final int id;
  final String main;
  final String description;
  final String icon;

  const WeatherCondition({
    required this.id,
    required this.main,
    required this.description,
    required this.icon,
  });

  factory WeatherCondition.fromJson(Map<String, dynamic> json) {
    return WeatherCondition(
      id: json['id'] as int,
      main: json['main'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
    );
  }

  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';

  String get emoji {
    switch (main.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'rain':
        return '🌧️';
      case 'drizzle':
        return '🌦️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'fog':
        return '🌫️';
      default:
        return '🌤️';
    }
  }
}

/// Temperature data
class TemperatureData {
  final double current;
  final double feelsLike;
  final double? minTemp;
  final double? maxTemp;
  final int humidity;
  final int pressure;

  const TemperatureData({
    required this.current,
    required this.feelsLike,
    this.minTemp,
    this.maxTemp,
    required this.humidity,
    required this.pressure,
  });

  factory TemperatureData.fromJson(Map<String, dynamic> json) {
    return TemperatureData(
      current: (json['current'] ?? json['temp'] as num).toDouble(),
      feelsLike: (json['feels_like'] as num).toDouble(),
      minTemp: (json['min_temp'] ?? json['temp_min'] as num?)?.toDouble(),
      maxTemp: (json['max_temp'] ?? json['temp_max'] as num?)?.toDouble(),
      humidity: json['humidity'] as int,
      pressure: json['pressure'] as int,
    );
  }
}

/// Wind data
class WindData {
  final double speed;
  final int? deg;
  final double? gust;

  const WindData({
    required this.speed,
    this.deg,
    this.gust,
  });

  factory WindData.fromJson(Map<String, dynamic> json) {
    return WindData(
      speed: (json['speed'] as num).toDouble(),
      deg: json['deg'] as int?,
      gust: (json['gust'] as num?)?.toDouble(),
    );
  }

  String get direction {
    if (deg == null) return '';
    final directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((deg! + 22.5) / 45).floor() % 8;
    return directions[index];
  }
}

/// Complete weather data
class WeatherData {
  final String locationName;
  final String countryCode;
  final double latitude;
  final double longitude;
  final List<WeatherCondition> conditions;
  final TemperatureData temperature;
  final WindData? wind;
  final int? visibility;
  final int? clouds;
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime dataTimestamp;
  final DateTime fetchedAt;

  const WeatherData({
    required this.locationName,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.conditions,
    required this.temperature,
    this.wind,
    this.visibility,
    this.clouds,
    this.sunrise,
    this.sunset,
    required this.dataTimestamp,
    required this.fetchedAt,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      locationName: json['location_name'] as String,
      countryCode: json['country_code'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      conditions: (json['conditions'] as List<dynamic>)
          .map((e) => WeatherCondition.fromJson(e as Map<String, dynamic>))
          .toList(),
      temperature:
          TemperatureData.fromJson(json['temperature'] as Map<String, dynamic>),
      wind: json['wind'] != null
          ? WindData.fromJson(json['wind'] as Map<String, dynamic>)
          : null,
      visibility: json['visibility'] as int?,
      clouds: json['clouds'] as int?,
      sunrise: json['sunrise'] != null
          ? DateTime.parse(json['sunrise'] as String)
          : null,
      sunset: json['sunset'] != null
          ? DateTime.parse(json['sunset'] as String)
          : null,
      dataTimestamp: DateTime.parse(json['data_timestamp'] as String),
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
    );
  }

  WeatherCondition? get primaryCondition =>
      conditions.isNotEmpty ? conditions.first : null;
}

/// Forecast item for a single day
class WeatherForecastItem {
  final DateTime date;
  final List<WeatherCondition> conditions;
  final double tempMin;
  final double tempMax;
  final int humidity;
  final double? windSpeed;
  final double? rainProbability;
  final String description;

  const WeatherForecastItem({
    required this.date,
    required this.conditions,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    this.windSpeed,
    this.rainProbability,
    required this.description,
  });

  factory WeatherForecastItem.fromJson(Map<String, dynamic> json) {
    return WeatherForecastItem(
      date: DateTime.parse(json['date'] as String),
      conditions: (json['conditions'] as List<dynamic>)
          .map((e) => WeatherCondition.fromJson(e as Map<String, dynamic>))
          .toList(),
      tempMin: (json['temp_min'] as num).toDouble(),
      tempMax: (json['temp_max'] as num).toDouble(),
      humidity: json['humidity'] as int,
      windSpeed: (json['wind_speed'] as num?)?.toDouble(),
      rainProbability: (json['rain_probability'] as num?)?.toDouble(),
      description: json['description'] as String,
    );
  }

  WeatherCondition? get primaryCondition =>
      conditions.isNotEmpty ? conditions.first : null;
}

/// Forecast response
class WeatherForecastResponse {
  final String locationName;
  final String countryCode;
  final double latitude;
  final double longitude;
  final List<WeatherForecastItem> forecast;
  final DateTime fetchedAt;

  const WeatherForecastResponse({
    required this.locationName,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.forecast,
    required this.fetchedAt,
  });

  factory WeatherForecastResponse.fromJson(Map<String, dynamic> json) {
    return WeatherForecastResponse(
      locationName: json['location_name'] as String,
      countryCode: json['country_code'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      forecast: (json['forecast'] as List<dynamic>)
          .map((e) => WeatherForecastItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
    );
  }
}

/// Trip weather response with packing suggestions
class TripWeatherResponse {
  final String tripId;
  final String locationName;
  final String countryCode;
  final List<WeatherForecastItem> forecast;
  final List<String> packingSuggestions;
  final DateTime fetchedAt;

  const TripWeatherResponse({
    required this.tripId,
    required this.locationName,
    required this.countryCode,
    required this.forecast,
    required this.packingSuggestions,
    required this.fetchedAt,
  });

  factory TripWeatherResponse.fromJson(Map<String, dynamic> json) {
    return TripWeatherResponse(
      tripId: json['trip_id'] as String,
      locationName: json['location_name'] as String,
      countryCode: json['country_code'] as String,
      forecast: (json['forecast'] as List<dynamic>)
          .map((e) => WeatherForecastItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      packingSuggestions: (json['packing_suggestions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
    );
  }
}
