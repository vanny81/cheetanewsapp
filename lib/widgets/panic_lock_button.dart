import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/auth/provider/stealth_provider.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';

class PanicLockButton extends StatefulWidget {
  const PanicLockButton({super.key});

  @override
  State<PanicLockButton> createState() => _PanicLockButtonState();
}

class _PanicLockButtonState extends State<PanicLockButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePanicLock() async {
    HapticFeedback.heavyImpact();
    await _controller.forward();
    await _controller.reverse();

    if (!mounted) return;
    
    // Lock the session
    final stealthProvider = Provider.of<StealthProvider>(context, listen: false);
    stealthProvider.lock();

    // Instantly route back to News Feed clearing navigation history
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.newsFeed,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        elevation: 6,
        onPressed: _handlePanicLock,
        child: const Icon(
          Icons.lock,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

/// A wrapper widget that overlays the panic lock button in the bottom-right corner of any screen.
class PanicLockWrapper extends StatelessWidget {
  final Widget child;
  final double rightOffset;
  final double bottomOffset;

  const PanicLockWrapper({
    super.key,
    required this.child,
    this.rightOffset = 16,
    this.bottomOffset = 80, // Default is offset above standard bottom tab bar
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          right: rightOffset,
          bottom: bottomOffset,
          child: const SafeArea(
            child: PanicLockButton(),
          ),
        ),
      ],
    );
  }
}
