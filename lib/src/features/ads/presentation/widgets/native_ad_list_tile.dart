import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/config/admob_config.dart';
import '../../../../core/services/logger_service.dart';
import '../providers/ads_providers.dart';

/// An inline **native** ad styled to sit inside a scrolling list (e.g. between
/// trip cards). Uses Google's built-in "medium" native template, themed to the
/// app's surface colour so it blends with surrounding cards.
///
/// Renders nothing for premium users / unsupported platforms / before load, so
/// it can be returned directly from a list builder without reserving space.
class NativeAdListTile extends ConsumerStatefulWidget {
  const NativeAdListTile({super.key, this.margin});

  /// Outer margin, so callers can match the surrounding list item spacing.
  final EdgeInsetsGeometry? margin;

  @override
  ConsumerState<NativeAdListTile> createState() => _NativeAdListTileState();
}

class _NativeAdListTileState extends ConsumerState<NativeAdListTile> {
  NativeAd? _ad;
  bool _loaded = false;
  bool _loading = false;
  bool _requested = false;

  /// Height for the medium template (Google recommends >= 320 logical px).
  static const double _mediumTemplateHeight = 320;

  static final AdRequest _request = AdRequest(
    keywords: const ['travel', 'trips', 'vacation', 'flights', 'hotels'],
  );

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _load(Color background, Color onSurface) {
    if (_requested || !AdMobConfig.isSupportedPlatform) return;
    _requested = true;
    _loading = true;

    final ad = NativeAd(
      adUnitId: AdMobConfig.nativeAdUnitId,
      request: _request,
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: background,
        cornerRadius: 16,
        primaryTextStyle: NativeTemplateTextStyle(textColor: onSurface),
        secondaryTextStyle: NativeTemplateTextStyle(textColor: onSurface),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad as NativeAd;
            _loaded = true;
            _loading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _loading = false;
          AppLogger.debug('Native ad failed to load: ${error.message}');
        },
      ),
    );
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(adsEnabledProvider);
    if (!enabled) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    if (!_loaded && !_loading) {
      _load(scheme.surface, scheme.onSurface);
    }

    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();

    return Padding(
      padding: widget.margin ?? const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: _mediumTemplateHeight,
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
