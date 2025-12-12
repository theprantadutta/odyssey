import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'animation_constants.dart';

/// Custom page transitions for GoRouter
/// Playful, bouncy transitions that feel delightful
class OdysseyTransitions {
  OdysseyTransitions._();

  /// Slide up with fade - for detail screens, forms
  /// Creates a feeling of content rising up to meet the user
  static CustomTransitionPage<T> slideUp<T>({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: AppAnimations.pageTransition,
      reverseTransitionDuration: AppAnimations.normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AppAnimations.pageEnter,
          reverseCurve: AppAnimations.pageExit,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
    );
  }

  /// Slide from right - for forward navigation
  static CustomTransitionPage<T> slideFromRight<T>({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: AppAnimations.pageTransition,
      reverseTransitionDuration: AppAnimations.normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AppAnimations.pageEnter,
          reverseCurve: AppAnimations.pageExit,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.25, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
    );
  }

  /// Shared axis horizontal - for peer/sibling navigation
  static CustomTransitionPage<T> sharedAxisHorizontal<T>({
    required Widget child,
    required GoRouterState state,
    bool reverse = false,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: AppAnimations.pageTransition,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AppAnimations.pageEnter,
        );

        final offsetTween = Tween<Offset>(
          begin: Offset(reverse ? -0.2 : 0.2, 0),
          end: Offset.zero,
        );

        return SlideTransition(
          position: offsetTween.animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
    );
  }

  /// Scale with fade - for modals, dialogs, popups
  /// Creates a bouncy zoom-in effect
  static CustomTransitionPage<T> scaleUp<T>({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: AppAnimations.normal,
      reverseTransitionDuration: AppAnimations.fast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AppAnimations.bouncyEnter,
          reverseCurve: AppAnimations.fadeOut,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  /// Fade through - for switching between unrelated destinations
  /// Simple and clean cross-fade
  static CustomTransitionPage<T> fadeThrough<T>({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: AppAnimations.normal,
      reverseTransitionDuration: AppAnimations.fast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: AppAnimations.fadeIn,
          ),
          child: child,
        );
      },
    );
  }

  /// Container transform - for card to detail transitions
  /// Simulates Material's container transform pattern
  static CustomTransitionPage<T> containerTransform<T>({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: AppAnimations.slow,
      reverseTransitionDuration: AppAnimations.normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AppAnimations.sharedElement,
        );

        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
            ),
          ),
          child: ScaleTransition(
            scale:
                Tween<double>(begin: 0.94, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  /// Bouncy enter - for playful screens like onboarding
  /// Extra bouncy entrance with scale
  static CustomTransitionPage<T> bouncyEnter<T>({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: AppAnimations.medium,
      reverseTransitionDuration: AppAnimations.fast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AppAnimations.bounce,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  /// No transition - for instant navigation
  static CustomTransitionPage<T> none<T>({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }
}

/// Extension on GoRoute for easier transition assignment
extension GoRouteTransitionExtension on GoRoute {
  /// Create a GoRoute with slide up transition
  static GoRoute slideUp({
    required String path,
    required Widget Function(BuildContext, GoRouterState) builder,
    String? name,
    List<RouteBase> routes = const [],
  }) {
    return GoRoute(
      path: path,
      name: name,
      routes: routes,
      pageBuilder: (context, state) => OdysseyTransitions.slideUp(
        child: builder(context, state),
        state: state,
      ),
    );
  }

  /// Create a GoRoute with fade through transition
  static GoRoute fadeThrough({
    required String path,
    required Widget Function(BuildContext, GoRouterState) builder,
    String? name,
    List<RouteBase> routes = const [],
  }) {
    return GoRoute(
      path: path,
      name: name,
      routes: routes,
      pageBuilder: (context, state) => OdysseyTransitions.fadeThrough(
        child: builder(context, state),
        state: state,
      ),
    );
  }
}
