import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:odyssey/src/common/utils/avatar_photo.dart';

void main() {
  const size = 96;

  Uint8List canvas(int r, int g, int b) {
    final bytes = Uint8List(size * size * 4);
    for (var i = 0; i < size * size; i++) {
      bytes[i * 4] = r;
      bytes[i * 4 + 1] = g;
      bytes[i * 4 + 2] = b;
      bytes[i * 4 + 3] = 255;
    }
    return bytes;
  }

  void paint(Uint8List bytes, int x, int y, int r, int g, int b) {
    final i = (y * size + x) * 4;
    bytes[i] = r;
    bytes[i + 1] = g;
    bytes[i + 2] = b;
  }

  test('a flat monogram is recognised', () {
    // Google's purple tile: one background colour, a letter in the middle.
    final image = canvas(0x7B, 0x4D, 0xBE);
    for (var y = 30; y < 66; y++) {
      for (var x = 38; x < 58; x++) {
        paint(image, x, y, 255, 255, 255);
      }
    }

    expect(
      AvatarPhoto.looksGenerated(image, width: size, height: size),
      isTrue,
    );
  });

  test('a photograph is not', () {
    final random = Random(7);
    final image = canvas(120, 120, 120);
    for (var i = 0; i < size * size; i++) {
      image[i * 4] = random.nextInt(256);
      image[i * 4 + 1] = random.nextInt(256);
      image[i * 4 + 2] = random.nextInt(256);
    }

    expect(
      AvatarPhoto.looksGenerated(image, width: size, height: size),
      isFalse,
    );
  });

  test('a portrait against a plain wall is still a photograph', () {
    // The hard case: a near-uniform background. Real light falls off across a
    // frame, and a few levels of gradient is enough to tell them apart.
    final image = canvas(200, 198, 195);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final falloff = (y * 20 ~/ size);
        paint(image, x, y, 200 - falloff, 198 - falloff, 195 - falloff);
      }
    }

    expect(
      AvatarPhoto.looksGenerated(image, width: size, height: size),
      isFalse,
    );
  });

  test('compression noise does not break a monogram', () {
    final image = canvas(0x7B, 0x4D, 0xBE);
    // A couple of levels of ringing, as a JPEG would leave.
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final wobble = ((x + y) % 3) - 1;
        paint(image, x, y, 0x7B + wobble, 0x4D + wobble, 0xBE + wobble);
      }
    }

    expect(
      AvatarPhoto.looksGenerated(image, width: size, height: size),
      isTrue,
    );
  });

  test('something unreadable is treated as a photograph', () {
    // Shows the picture rather than silently hiding it.
    expect(
      AvatarPhoto.looksGenerated(Uint8List(4), width: 96, height: 96),
      isFalse,
    );
    expect(
      AvatarPhoto.looksGenerated(canvas(10, 10, 10), width: 2, height: 2),
      isFalse,
    );
  });
}
