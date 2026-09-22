import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// An exception whose text was written for the person using the app.
///
/// Implementing this is a promise: [userMessage] is prose somebody wrote for a
/// user, it names no internals, and it is safe to put on screen in a release
/// build. Everything that does not implement it is treated as a developer
/// artefact and never shown.
abstract interface class UserFacingException implements Exception {
  String get userMessage;
}

/// Decides what a failure is allowed to say to the person using the app.
///
/// The rule is an allowlist, not a filter. Text reaches a release build only
/// when something deliberately wrote it for a user - a [UserFacingException],
/// or copy passed in at the call site. Everything else is described in general
/// terms, however informative the original might have been.
///
/// This exists because the opposite was shipped. `state.error` is
/// `e.toString()` in every provider in this app, and the error screen rendered
/// it verbatim, so a user hit a failed database migration and was shown
/// `SqliteException(1): while executing, duplicate column name: reason,
/// SQL logic error (code 1)` - the storage engine, the schema, a column name,
/// and the fact that a migration was mid-flight. None of that is the user's to
/// know, and all of it is worth having if you are looking for a way in.
///
/// Detail is not lost, only re-aimed: it still goes to the log in every build,
/// and [detailFor] hands it back in debug so the console and the screen say the
/// same thing while developing.
abstract final class FailureMessage {
  /// What a release build may show for [error].
  ///
  /// [fallback] is the caller's own words for this particular action - 'That
  /// trip could not be saved.' reads better than anything a general classifier
  /// can produce, and the caller knows what was being attempted.
  static String of(
    Object? error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    final message = _classify(error);
    return message ?? fallback;
  }

  /// The raw text, in debug builds only.
  ///
  /// Always null in release. Anything rendering this must accept null and show
  /// nothing, rather than fall back to the original object.
  static String? detailFor(Object? error) {
    if (kReleaseMode || error == null) return null;
    final text = error.toString();
    return text.isEmpty ? null : text;
  }

  /// Recognised failures a user can act on. Null means 'nothing safe to say'.
  static String? _classify(Object? error) {
    if (error == null) return null;

    // Written for a user by us.
    if (error is UserFacingException) return error.userMessage;

    if (error is SocketException) return _offline;
    if (error is TimeoutException) return _timeout;
    if (error is HttpException) return _offline;

    if (error is DioException) return _fromDio(error);

    // A string reaching here is almost always `e.toString()` from a provider,
    // which is the very thing this class exists to stop. It is only trusted
    // when it is one of the sentences the network layer already wrote.
    if (error is String) return _knownCopy.contains(error) ? error : null;

    return null;
  }

  static String? _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return _timeout;
      case DioExceptionType.connectionError:
        return _offline;
      case DioExceptionType.cancel:
        return null;
      case DioExceptionType.badCertificate:
        return 'The connection could not be trusted. Try a different network.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    // Deliberately by status, not by the server's own words. A backend message
    // is written for whoever is reading the logs, and on a 500 it is as likely
    // to be a stack trace as a sentence.
    switch (error.response?.statusCode) {
      case 400:
      case 422:
        return 'Some of that was not accepted. Check the details and try again.';
      case 401:
        return 'Your session has expired. Sign in again.';
      case 403:
        return 'You do not have access to that.';
      case 404:
        return 'That could not be found.';
      case 409:
        return 'That has changed since you last loaded it. Refresh and try again.';
      case 413:
        return 'That file is too large to upload.';
      case 429:
        return 'Too many attempts. Wait a moment and try again.';
      case final int code when code >= 500:
        return 'Something went wrong on our side. Try again shortly.';
    }

    if (error.error is SocketException) return _offline;
    return null;
  }

  static const _offline =
      'You appear to be offline. Check your connection and try again.';
  static const _timeout = 'That took too long. Try again in a moment.';

  /// The sentences [ErrorInterceptor] substitutes onto a [DioException].
  ///
  /// They arrive as a plain string in `DioException.error`, already safe, and
  /// this is what tells them apart from a raw `toString()` that happens to be
  /// a string too.
  static const _knownCopy = {
    'Connection timeout. Please check your internet connection.',
    'No internet connection. Please check your network.',
    'An unexpected error occurred. Please try again.',
    'Something went wrong. Please try again.',
    'Request cancelled',
  };
}
