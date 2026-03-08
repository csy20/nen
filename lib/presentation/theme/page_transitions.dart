import 'package:flutter/material.dart';

/// Custom page route with slide + fade transitions.
/// Slides up and fades in on enter, slides down and fades out on exit.
class NenPageRoute<T> extends PageRouteBuilder<T> {
  NenPageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Respect reduced motion preference
            final reduceMotion =
                MediaQuery.of(context).disableAnimations;
            if (reduceMotion) return child;

            final fadeIn = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            );
            final slideUp = Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(fadeIn);

            return SlideTransition(
              position: slideUp,
              child: FadeTransition(
                opacity: fadeIn,
                child: child,
              ),
            );
          },
        );
}

/// Slide-from-right transition for "going deeper" navigation.
class NenSlideRoute<T> extends PageRouteBuilder<T> {
  NenSlideRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final reduceMotion =
                MediaQuery.of(context).disableAnimations;
            if (reduceMotion) return child;

            final slideIn = Tween<Offset>(
              begin: const Offset(0.15, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ));

            return SlideTransition(
              position: slideIn,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
        );
}
