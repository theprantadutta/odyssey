import 'dart:typed_data';

/// Tells a real profile photograph from the monogram a provider generates for
/// an account that never set one.
///
/// Google returns a picture for every account. When the user has not uploaded
/// one it is a flat coloured square with their first letter in it, served from
/// the same host, under the same opaque `/a/ACg8oc…=s96-c` path as a real
/// photo. Nothing about the URL distinguishes them, so the image itself has to
/// be looked at.
///
/// The tell is the border. A generated monogram is one solid colour with a
/// glyph centred in it, so every pixel around the edge is identical. A
/// photograph is not: even a portrait against a plain wall varies by a few
/// levels across the frame from lighting alone.
///
/// Wrong in one direction only, by design. A photograph with a genuinely
/// uniform border - a flat studio backdrop - is taken for a monogram and the
/// account keeps its Odyssey initial, which is a tidy-looking outcome. The
/// reverse, showing someone else's palette in place of ours, is the one the
/// design cannot absorb.
abstract final class AvatarPhoto {
  /// How far apart two border samples may be, per channel, and still count as
  /// the same colour. Generous enough for JPEG ringing around the edge.
  static const int _tolerance = 6;

  /// Whether [rgba] - straight RGBA bytes, [width] x [height] - looks like a
  /// provider-generated monogram.
  ///
  /// Returns false for anything it cannot read, so an unexpected format shows
  /// the picture rather than silently hiding it.
  static bool looksGenerated(
    Uint8List rgba, {
    required int width,
    required int height,
  }) {
    if (width < 8 || height < 8) return false;
    if (rgba.length < width * height * 4) return false;

    ({int r, int g, int b}) at(int x, int y) {
      final i = (y * width + x) * 4;
      return (r: rgba[i], g: rgba[i + 1], b: rgba[i + 2]);
    }

    // Sampled around the perimeter, inset slightly so a rounded or antialiased
    // corner does not decide it. A centred glyph never reaches any of these.
    final maxX = width - 1;
    final maxY = height - 1;
    final insetX = (width * 0.08).round().clamp(1, width ~/ 4);
    final insetY = (height * 0.08).round().clamp(1, height ~/ 4);
    final midX = width ~/ 2;
    final midY = height ~/ 2;

    final samples = [
      at(insetX, insetY),
      at(maxX - insetX, insetY),
      at(insetX, maxY - insetY),
      at(maxX - insetX, maxY - insetY),
      at(midX, insetY),
      at(midX, maxY - insetY),
      at(insetX, midY),
      at(maxX - insetX, midY),
    ];

    final first = samples.first;
    for (final sample in samples.skip(1)) {
      if ((sample.r - first.r).abs() > _tolerance ||
          (sample.g - first.g).abs() > _tolerance ||
          (sample.b - first.b).abs() > _tolerance) {
        return false;
      }
    }
    return true;
  }
}
