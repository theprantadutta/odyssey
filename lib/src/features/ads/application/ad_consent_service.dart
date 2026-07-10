import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/admob_config.dart';
import '../../../core/services/logger_service.dart';

/// Wraps Google's User Messaging Platform (UMP) consent flow.
///
/// Key behaviour — the consent form is **geography-aware by design**:
/// `requestConsentInfoUpdate` asks Google whether this user (by region) needs a
/// consent form. For users outside the EEA/UK (and other regulated regions) no
/// form is ever shown and [canRequestAds] becomes true immediately. EEA/UK
/// users see the form exactly once, and ads only start after they answer.
///
/// We never block app startup on this — [gather] runs in the background and the
/// `adsEnabled` provider simply waits for [canRequestAds] to flip true.
class AdConsentService {
  AdConsentService._();
  static final AdConsentService instance = AdConsentService._();

  bool _canRequestAds = false;

  /// Whether the SDK is cleared to request ads (consent obtained OR not
  /// required for this user's region). False until [gather] resolves.
  bool get canRequestAds => _canRequestAds;

  /// Runs the UMP flow once. Safe to call again (it just re-checks status).
  ///
  /// [debugGeography] / [testIdentifiers] / [resetForTesting] are for local
  /// testing only — e.g. pass [DebugGeography.debugGeographyEea] on a test
  /// device to force the consent form to appear. Leave them unset in normal use.
  Future<bool> gather({
    bool resetForTesting = false,
    DebugGeography? debugGeography,
    List<String> testIdentifiers = const [],
  }) async {
    if (!AdMobConfig.isSupportedPlatform) {
      _canRequestAds = false;
      return false;
    }

    try {
      if (resetForTesting) {
        await ConsentInformation.instance.reset();
      }

      final debugSettings =
          (debugGeography != null || testIdentifiers.isNotEmpty)
              ? ConsentDebugSettings(
                  debugGeography: debugGeography,
                  testIdentifiers: testIdentifiers,
                )
              : null;

      final params = ConsentRequestParameters(
        consentDebugSettings: debugSettings,
      );

      // Step 1: refresh consent info for this user/region.
      final updateCompleter = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        updateCompleter.complete,
        (FormError error) {
          if (!updateCompleter.isCompleted) {
            updateCompleter.completeError(error);
          }
        },
      );
      await updateCompleter.future;

      // Step 2: show the form ONLY if Google says it's required. Completes
      // immediately (no UI) for users who don't need it.
      await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        if (error != null) {
          AppLogger.warning(
            'UMP consent form error: ${error.errorCode} ${error.message}',
          );
        }
      });

      // Step 3: on iOS, show Apple's ATT prompt (after UMP, before ads). Per
      // Google's guidance the UMP form comes first; ATT then covers Apple's
      // NSUserTrackingUsageDescription requirement for personalized ads.
      await requestAttIfNeeded();

      // Step 4: final gate.
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      AppLogger.info('AdMob consent resolved: canRequestAds=$_canRequestAds');
    } catch (e, st) {
      // On any failure, fall back to whatever the SDK already knows. For
      // non-regulated regions this is typically still true, so ads keep working.
      AppLogger.warning('UMP consent flow failed, falling back: $e');
      // Still surface the ATT prompt so Apple's tracking requirement is met
      // even when the UMP flow errors out. Idempotent (no-op once resolved).
      await requestAttIfNeeded();
      try {
        _canRequestAds = await ConsentInformation.instance.canRequestAds();
      } catch (_) {
        _canRequestAds = false;
        AppLogger.error('Could not determine ad consent status', e, st);
      }
    }

    return _canRequestAds;
  }

  /// Shows Apple's App Tracking Transparency (ATT) prompt on iOS when the user
  /// hasn't yet been asked. No-op on every other platform (and on web).
  ///
  /// Apple requires this prompt to appear before tracking / personalized ads
  /// whenever the app ships an `NSUserTrackingUsageDescription` (it does). We
  /// call it after the UMP consent form resolves and before ads are requested.
  /// Failures are swallowed and logged — ATT must never block app startup.
  Future<void> requestAttIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // A short delay lets the app finish presenting its first frame so the
        // system prompt isn't shown mid-launch (Apple/Google guidance).
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final result =
            await AppTrackingTransparency.requestTrackingAuthorization();
        AppLogger.info('ATT authorization resolved: $result');
      } else {
        AppLogger.info('ATT already resolved: $status');
      }
    } catch (e, st) {
      AppLogger.error('ATT request failed', e, st);
    }
  }
}
