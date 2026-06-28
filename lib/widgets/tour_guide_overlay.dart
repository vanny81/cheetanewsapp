import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';

/// A one-time tour guide overlay that teaches the user about the hidden
/// triple-tap gesture to access the secret chat feature.
///
/// Shows only once after first installation. Uses [SecurePrefs] to persist
/// the "has seen tour" flag so it never appears again.
class TourGuideOverlay extends StatefulWidget {
  /// The GlobalKey of the widget the arrow should point at (the AppBar title).
  final GlobalKey targetKey;

  const TourGuideOverlay({super.key, required this.targetKey});

  @override
  State<TourGuideOverlay> createState() => _TourGuideOverlayState();
}

class _TourGuideOverlayState extends State<TourGuideOverlay>
    with TickerProviderStateMixin {
  static const String _tourSeenKey = 'news_feed_tour_seen';

  bool _shouldShow = false;
  bool _isVisible = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Fade in/out controller
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Bouncing hand animation
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bounceAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
    _bounceController.repeat(reverse: true);

    // Subtle pulse glow on the message card
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _checkIfShouldShow();
  }

  Future<void> _checkIfShouldShow() async {
    final seen = await SecurePrefs.getBool(_tourSeenKey);
    if (!seen && mounted) {
      // Small delay to let the screen render first
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {
          _shouldShow = true;
          _isVisible = true;
        });
        _fadeController.forward();
      }
    }
  }

  Future<void> _dismiss() async {
    await SecurePrefs.setBool(_tourSeenKey, true);
    await _fadeController.reverse();
    if (mounted) {
      setState(() {
        _isVisible = false;
        _shouldShow = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bounceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();

    // Calculate target position
    Offset targetCenter = Offset.zero;
    double targetWidth = 0;
    final RenderBox? renderBox =
        widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      targetCenter = Offset(
        position.dx + size.width / 2,
        position.dy + size.height / 2,
      );
      targetWidth = size.width;
    }

    // If we can't find the target, use a sensible default (center-top area)
    if (targetCenter == Offset.zero) {
      final screenWidth = MediaQuery.of(context).size.width;
      targetCenter = Offset(screenWidth / 2, kToolbarHeight + MediaQuery.of(context).padding.top);
      targetWidth = 180;
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        if (!_isVisible && _fadeAnimation.value == 0) {
          return const SizedBox.shrink();
        }
        return Opacity(
          opacity: _fadeAnimation.value,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _dismiss,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withValues(alpha: 0.75),
            child: Stack(
              children: [
                // ── Spotlight cutout highlight on the target ──
                Positioned(
                  left: targetCenter.dx - (targetWidth / 2) - 16,
                  top: targetCenter.dy - 24,
                  child: Container(
                    width: targetWidth + 32,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xffFCC604),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffFCC604).withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Animated pointing hand icon ──
                AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Positioned(
                      left: targetCenter.dx - 16,
                      top: targetCenter.dy + 28 + _bounceAnimation.value,
                      child: child!,
                    );
                  },
                  child: const Text(
                    '👆',
                    style: TextStyle(fontSize: 36),
                  ),
                ),

                // ── Message card ──
                Positioned(
                  left: 24,
                  right: 24,
                  top: targetCenter.dy + 90,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final glowOpacity = 0.15 + (_pulseAnimation.value * 0.15);
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xffFCC604)
                                  .withValues(alpha: glowOpacity),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xff2a2a2a),
                            Color(0xff1e1e1e),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xffFCC604).withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Secret icon badge
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xffFCC604),
                                  Color(0xffE5A100),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xffFCC604)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.lock_open_rounded,
                              color: Colors.black,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title
                          const Text(
                            'Hidden Feature',
                            style: TextStyle(
                              color: Color(0xffFCC604),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Message
                          RichText(
                            textAlign: TextAlign.center,
                            text: const TextSpan(
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                height: 1.5,
                              ),
                              children: [
                                TextSpan(text: 'Tap the word '),
                                TextSpan(
                                  text: 'CheetaNews',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(text: ' '),
                                TextSpan(
                                  text: '3 times',
                                  style: TextStyle(
                                    color: Color(0xffFCC604),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: ' to access the hidden secret chat',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Warning notice
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffFF9800)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xffFF9800)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xffFF9800),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Once you close this message you will never see it again!',
                                    style: TextStyle(
                                      color: Color(0xffFF9800),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Help link
                          RichText(
                            textAlign: TextAlign.center,
                            text: const TextSpan(
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                                height: 1.5,
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      'If you are stuck and need help you can visit ',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse(
                                  'https://cheetanewsapp.site');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                            child: const Text(
                              'https://cheetanewsapp.site',
                              style: TextStyle(
                                color: Color(0xff64B5F6),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xff64B5F6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'for more information about the app.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Got it button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _dismiss,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xffFCC604),
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                                shadowColor: const Color(0xffFCC604)
                                    .withValues(alpha: 0.4),
                              ),
                              child: const Text(
                                'Got it!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
