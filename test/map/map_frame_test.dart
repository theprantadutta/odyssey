import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:odyssey/src/features/map/domain/map_frame.dart';

void main() {
  const width = 390.0;
  const height = 780.0;

  const newYork = LatLng(40.71, -74.01);
  const bali = LatLng(-8.34, 115.09);
  const london = LatLng(51.51, -0.13);
  const paris = LatLng(48.86, 2.35);

  /// How far east of [centre] a longitude sits, in degrees, going the short way.
  double offsetFrom(double centre, double lon) {
    var d = (lon - centre) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }

  test('nothing to frame', () {
    expect(MapFrame.of([], width: width, height: height), isNull);
  });

  test('two trips either side of the antimeridian centre on the Pacific', () {
    final frame = MapFrame.of([newYork, bali], width: width, height: height)!;

    // Not Africa. The naive midpoint of -74 and 115 is 20.5, which is the one
    // stretch of the globe neither trip is anywhere near.
    expect(frame.centre.longitude, lessThan(-140));
    expect(frame.centre.longitude, greaterThan(-180));

    // And each trip is within half the arc of that centre, so both are on the
    // same side of the world as the camera.
    expect(offsetFrom(frame.centre.longitude, newYork.longitude).abs(), lessThan(90));
    expect(offsetFrom(frame.centre.longitude, bali.longitude).abs(), lessThan(90));
  });

  test('trips in one region frame tightly around them', () {
    final frame = MapFrame.of([london, paris], width: width, height: height)!;

    expect(frame.centre.longitude, closeTo(1.11, 0.5));
    expect(frame.centre.latitude, closeTo(50.18, 0.5));

    // A 2.5 degree spread should zoom in a long way, not sit at world view.
    expect(frame.zoom, greaterThan(5));
  });

  test('a single trip is centred on itself at the closest zoom', () {
    final frame = MapFrame.of([paris], width: width, height: height)!;

    expect(frame.centre.latitude, closeTo(paris.latitude, 0.001));
    expect(frame.centre.longitude, closeTo(paris.longitude, 0.001));
    expect(frame.zoom, 12);
  });

  test('zoom never exceeds the bounds it is given', () {
    final spread = MapFrame.of(
      [newYork, bali, london],
      width: width,
      height: height,
      minZoom: 2,
      maxZoom: 8,
    )!;
    expect(spread.zoom, inInclusiveRange(2, 8));
  });

  test('longitude comes back inside the usual range', () {
    for (final points in [
      [newYork, bali],
      [london, paris],
      [const LatLng(0, 179), const LatLng(0, -179)],
    ]) {
      final frame = MapFrame.of(points, width: width, height: height)!;
      expect(frame.centre.longitude, inInclusiveRange(-180, 180));
    }
  });

  test('the zoom floor is where the world still covers the viewport', () {
    // 780 tall needs the world to be at least 780px, and it is 256px at zoom 0,
    // so a little over 1.6.
    expect(MapFrame.minZoomFor(780), closeTo(1.607, 0.01));

    // At that zoom the world is at least as tall as the viewport.
    final worldSize = 256 * math.pow(2, MapFrame.minZoomFor(780));
    expect(worldSize, greaterThanOrEqualTo(780));
  });

  test('a globe-spanning pair still frames both inside the viewport', () {
    const height = 780.0;
    final floor = MapFrame.minZoomFor(height);
    final frame = MapFrame.of(
      [newYork, bali],
      width: width,
      height: height,
      minZoom: floor,
    )!;

    // Clamped to the floor, so the map still fills the screen...
    expect(frame.zoom, closeTo(floor, 0.001));

    // ...and at that zoom the visible span of longitude is wide enough to hold
    // both trips either side of the centre.
    final visibleLon = 360 * width / (256 * math.pow(2, frame.zoom));
    for (final trip in [newYork, bali]) {
      expect(
        offsetFrom(frame.centre.longitude, trip.longitude).abs(),
        lessThan(visibleLon / 2),
        reason: 'trip at ${trip.longitude} must be on screen',
      );
    }
  });

  test('the viewport never hangs off the top or bottom of the world', () {
    const height = 780.0;

    // Trips well north of the equator, at a zoom where the world is only just
    // taller than the screen. Centring on their midpoint would leave a band of
    // empty canvas above the map.
    final frame = MapFrame.of(
      [newYork, bali],
      width: width,
      height: height,
      minZoom: MapFrame.minZoomFor(height),
    )!;

    final worldPixels = 256 * math.pow(2, frame.zoom);
    final halfSpan = math.pi * height / worldPixels;
    final centreY = math.log(
      math.tan(math.pi / 4 + frame.centre.latitude * math.pi / 360),
    );

    expect(
      centreY.abs() + halfSpan,
      lessThanOrEqualTo(math.pi + 0.001),
      reason: 'the visible strip must stay within the projected world',
    );
  });

  test('a tightly framed pair keeps its own centre', () {
    // Zoomed right in, there is acres of world either side, so nothing is
    // clamped and the centre stays where the trips put it.
    final frame = MapFrame.of([london, paris], width: width, height: height)!;
    expect(frame.centre.latitude, closeTo(50.18, 0.5));
  });

  test('a pair straddling the antimeridian centres on it, not on zero', () {
    final frame = MapFrame.of(
      [const LatLng(0, 179), const LatLng(0, -179)],
      width: width,
      height: height,
    )!;

    // Two degrees apart across the line. The centre belongs at 180, and the
    // arc is 2 degrees wide - not 358 centred on Greenwich.
    expect(frame.centre.longitude.abs(), closeTo(180, 0.001));
    expect(frame.zoom, greaterThan(5));
  });
}
