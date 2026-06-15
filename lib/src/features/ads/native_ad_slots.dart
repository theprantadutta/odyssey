import 'ad_constants.dart';

/// Helper for interleaving inline native ads into a scrolling list.
///
/// Encapsulates the index math so every list (trips, templates, achievements,
/// shared trips) injects ads the same way: one native ad after every
/// [AdConstants.nativeAdEveryNItems] real items, but only once the list has at
/// least [AdConstants.nativeAdMinItemsBeforeFirst] items.
///
/// Usage in a list builder:
/// ```dart
/// final slots = NativeAdSlots(items.length);
/// ListView.builder(
///   itemCount: slots.totalCount,
///   itemBuilder: (context, index) {
///     if (slots.isAdAt(index)) return const NativeAdListTile();
///     final item = items[slots.realIndexAt(index)];
///     ...
///   },
/// );
/// ```
class NativeAdSlots {
  const NativeAdSlots(this.realCount);

  /// Number of real (non-ad) items in the list.
  final int realCount;

  bool get _enabled => realCount >= AdConstants.nativeAdMinItemsBeforeFirst;

  /// A "block" is N real items followed by 1 ad.
  int get _block => AdConstants.nativeAdEveryNItems + 1;

  /// How many ad tiles will be injected.
  int get adCount =>
      _enabled ? realCount ~/ AdConstants.nativeAdEveryNItems : 0;

  /// Total list length including ads (use as `itemCount`).
  int get totalCount => realCount + adCount;

  /// Whether the interleaved [index] is an ad slot.
  bool isAdAt(int index) =>
      _enabled && index % _block == AdConstants.nativeAdEveryNItems;

  /// Maps an interleaved [index] back to the real-items index.
  int realIndexAt(int index) => index - (index ~/ _block);
}
