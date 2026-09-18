import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/admob_config.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/startup_prompt_queue.dart';

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
  bool _privacyOptionsRequired = false;

  /// Whether the SDK is cleared to request ads (consent obtained OR not
  /// required for this user's region). False until [gather] resolves.
  bool get canRequestAds => _canRequestAds;

  /// Whether this user must be given a way to change their consent later.
  ///
  /// True for users whose region required a consent form. UMP requires the app
  /// to offer a persistent entry point in these cases - consent that can be
  /// given once and never revisited is not consent - and the settings entry is
  /// hidden for everyone else, where the form would do nothing.
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  /// Notifies when consent changes, so ad eligibility can be recomputed.
  ///
  /// Withdrawing consent has to actually stop the ads that are already on
  /// screen. Without this the gate keeps its old answer until something else
  /// happens to rebuild it, and a user who just opted out keeps seeing exactly
  /// what they opted out of.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

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
      //
      // Queued, because the notification permission prompt goes up during
      // startup too. Two system modals presented at once are drawn over each
      // other, and an answer meant for one can land on the other - consent
      // answered by accident is worse than consent not asked for.
      await StartupPromptQueue.instance.enqueue('ump-consent', () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) {
            AppLogger.warning(
              'UMP consent form error: ${error.errorCode} ${error.message}',
            );
          }
        });
      });

      // Recorded after the form, because answering it is what can make the
      // privacy entry point necessary.
      await _refreshPrivacyOptionsRequirement();

      // Step 3: on iOS, show Apple's ATT prompt (after UMP, before ads). Per
      // Google's guidance the UMP form comes first; ATT then covers Apple's
      // NSUserTrackingUsageDescription requirement for personalized ads.
      await requestAttIfNeeded();

      // Step 4: final gate.
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      AppLogger.info(
        'AdMob consent resolved: canRequestAds=$_canRequestAds, '
        'privacyOptionsRequired=$_privacyOptionsRequired',
      );
    } catch (e, st) {
      // On any failure, fall back to whatever the SDK already knows. For
      // non-regulated regions this is typically still true, so ads keep working.
      AppLogger.warning('UMP consent flow failed, falling back: $e');
      // Still surface the ATT prompt so Apple's tracking requirement is met
      // even when the UMP flow errors out. Idempotent (no-op once resolved).
      await requestAttIfNeeded();
      try {
        _canRequestAds = await ConsentInformation.instance.canRequestAds();
        await _refreshPrivacyOptionsRequirement();
      } catch (_) {
        // Nothing is known, so nothing is assumed: no ads. Being wrong in this
        // direction costs revenue; being wrong in the other breaks the law.
        _canRequestAds = false;
        AppLogger.error('Could not determine ad consent status', e, st);
      }
    }

    revision.value++;
    return _canRequestAds;
  }

  /// Reads whether a privacy entry point has to be offered.
  ///
  /// Failures leave the previous answer alone rather than hiding the entry
  /// point: a user who was entitled to change their mind yesterday still is.
  Future<void> _refreshPrivacyOptionsRequirement() async {
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();

      _privacyOptionsRequired =
          status == PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      AppLogger.warning('Could not read the privacy options requirement: $e');
    }
  }

  /// Shows the UMP privacy options form, so a user can change their consent.
  ///
  /// Returns whether ads may still be requested afterwards. The answer is acted
  /// on by the caller: consent withdrawn has to take effect now, on the ads
  /// already on screen, not at some later rebuild.
  Future<bool> showPrivacyOptions() async {
    if (!AdMobConfig.isSupportedPlatform) return _canRequestAds;

    final error = await StartupPromptQueue.instance.enqueue<FormError?>(
      'ump-privacy-options',
      () async {
        final completer = Completer<FormError?>();
        ConsentForm.showPrivacyOptionsForm(completer.complete);
        return completer.future;
      },
    );

    if (error != null) {
      AppLogger.warning(
        'UMP privacy options error: ${error.errorCode} ${error.message}',
      );
    }

    // Re-read rather than assume. Withdrawing consent can flip this to false,
    // and it is the only thing that tells the ad gates to shut.
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      await _refreshPrivacyOptionsRequirement();
    } catch (e) {
      AppLogger.error('Could not re-read consent after a privacy change', e);
      _canRequestAds = false;
    }

    AppLogger.info('Consent after privacy options: canRequestAds=$_canRequestAds');

    revision.value++;
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
        // Queued behind the UMP form and the notification prompt. The delay
        // below is still wanted - it lets the first frame present - but a delay
        // alone never guaranteed the other prompts were finished.
        await StartupPromptQueue.instance.enqueue('att', () async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          final result =
              await AppTrackingTransparency.requestTrackingAuthorization();
          AppLogger.info('ATT authorization resolved: $result');
        });
      } else {
        AppLogger.info('ATT already resolved: $status');
      }
    } catch (e, st) {
      AppLogger.error('ATT request failed', e, st);
    }
  }
}
