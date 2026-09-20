import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Where to put the camera so that a set of places is all on screen at once.
///
/// Exists because longitude is a circle and the obvious arithmetic treats it as
/// a line. Take trips in New York (-74°) and Bali (115°): min/max says they
/// span 189° and sit either side of 20°E, which centres the map on Africa and
/// pushes both trips off a portrait screen. Going the other way, across the
/// Pacific, they span 171° and centre near -160°, which puts one on each side
/// of the screen with both visible. The short way round is the right way, and
/// it is the one that crosses the antimeridian.
class MapFrame {
  const MapFrame({required this.centre, required this.zoom});

  final LatLng centre;
  final double zoom;

  /// The edge length of a map tile, and so of the whole world at zoom 0.
  static const double _tileSize = 256;

  /// The lowest zoom at which the world still covers a viewport [height] tall.
  ///
  /// Below it the projection stops short of the viewport's edges and the map
  /// sits in bands of empty canvas. Used as a floor rather than flutter_map's
  /// [CameraConstraint.containLatitude], which refuses a camera that is zoomed
  /// out too far instead of correcting it - and so silently cancels the move.
  static double minZoomFor(double height) =>
      _log2(height / _tileSize).clamp(0.0, 4.0).toDouble();

  /// Frames [points] inside a viewport of [width] x [height] logical pixels.
  ///
  /// [padding] is kept clear on every side, so pins do not sit under the header
  /// or the tab bar. Returns null when there is nothing to frame.
  static MapFrame? of(
    List<LatLng> points, {
    required double width,
    required double height,
    double padding = 56,
    double minZoom = 1,
    double maxZoom = 12,
  }) {
    if (points.isEmpty) return null;

    final usableWidth = math.max(width - padding * 2, 1.0);
    final usableHeight = math.max(height - padding * 2, 1.0);

    final (centreLon, lonSpan) = _longitudeArc(points);

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
    }

    // Latitude is measured in projected units, not degrees: on a Mercator map a
    // degree near the pole is far taller on screen than one at the equator.
    final latSpan = (_mercatorY(maxLat) - _mercatorY(minLat)).abs();

    final zoomForWidth = lonSpan <= 0
        ? maxZoom
        : _log2(usableWidth / (_tileSize * (lonSpan / 360)));
    final zoomForHeight = latSpan <= 0
        ? maxZoom
        : _log2(usableHeight / (_tileSize * (latSpan / (2 * math.pi))));

    final zoom = math
        .min(zoomForWidth, zoomForHeight)
        .clamp(minZoom, maxZoom)
        .toDouble();

    return MapFrame(
      centre: LatLng(
        _clampLatitudeToWorld(
          (minLat + maxLat) / 2,
          zoom: zoom,
          viewportHeight: height,
        ),
        centreLon,
      ),
      zoom: zoom,
    );
  }

  /// Pulls a centre latitude back until the viewport sits wholly on the world.
  ///
  /// At the zoom floor the world is only just as tall as the screen, so a
  /// centre anywhere other than the equator hangs part of the viewport off the
  /// top or the bottom - which shows up as a band of empty canvas above the
  /// map, easily mistaken for a status bar.
  static double _clampLatitudeToWorld(
    double latitude, {
    required double zoom,
    required double viewportHeight,
  }) {
    final worldPixels = _tileSize * math.pow(2, zoom);
    // Half the viewport, measured in the projection's own units.
    final halfSpan = math.pi * viewportHeight / worldPixels;
    final limit = math.pi - halfSpan;

    // The world is shorter than the viewport: nothing can hide the gap, so at
    // least centre it rather than leaving it all at one end.
    if (limit <= 0) return 0;

    final y = _mercatorY(latitude).clamp(-limit, limit).toDouble();
    return _latitudeFromMercatorY(y);
  }

  /// The inverse of [_mercatorY].
  static double _latitudeFromMercatorY(double y) =>
      (2 * math.atan(math.exp(y)) - math.pi / 2) * 180 / math.pi;

  /// The centre and width, in degrees, of the shortest arc of longitude that
  /// contains every point.
  ///
  /// Found by looking for the widest *empty* stretch instead: whatever is left
  /// once the biggest gap is removed is the tightest arc that holds them all.
  static (double centre, double span) _longitudeArc(List<LatLng> points) {
    final lons = points.map((p) => p.longitude).toList()..sort();
    if (lons.length == 1) return (lons.first, 0);

    var gapStart = lons.last;
    var widestGap = 360 - (lons.last - lons.first);

    for (var i = 0; i < lons.length - 1; i++) {
      final gap = lons[i + 1] - lons[i];
      if (gap > widestGap) {
        widestGap = gap;
        gapStart = lons[i];
      }
    }

    final span = 360 - widestGap;
    // The arc runs from the far side of the gap, eastward, for `span` degrees.
    final centre = _normaliseLongitude(gapStart + widestGap + span / 2);
    return (centre, span);
  }

  static double _normaliseLongitude(double lon) {
    var l = (lon + 180) % 360;
    if (l < 0) l += 360;
    return l - 180;
  }

  /// Spherical Mercator's y, in radians, for a latitude in degrees.
  static double _mercatorY(double latitude) {
    // Clamped short of the poles, where the projection runs to infinity.
    final lat = latitude.clamp(-85.05112878, 85.05112878);
    final rad = lat * math.pi / 180;
    return math.log(math.tan(math.pi / 4 + rad / 2));
  }

  static double _log2(double value) =>
      value <= 0 ? 0 : math.log(value) / math.ln2;
}
