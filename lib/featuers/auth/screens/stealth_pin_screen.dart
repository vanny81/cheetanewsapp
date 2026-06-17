import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/auth/provider/stealth_provider.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/global.dart';

class StealthPinScreen extends StatefulWidget {
  const StealthPinScreen({super.key});

  @override
  State<StealthPinScreen> createState() => _StealthPinScreenState();
}

class _StealthPinScreenState extends State<StealthPinScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _currentInput = [];
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // PIN Setup States
  bool _isConfirming = false;
  String _firstEnteredPin = "";

  // Navigation guard to prevent double-navigation and provider rebuild conflicts
  bool _isNavigating = false;

  // Cached provider reference — captured in didChangeDependencies so we never
  // access BuildContext across async gaps (which triggers _dependents.isEmpty assertion).
  StealthProvider? _stealthProvider;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 24.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController)
      ..addStatusListener((status) {
        // FIX: Guard with mounted check — the status listener fires asynchronously.
        // Without this, if navigation begins (dispose called) while the shake animation
        // is mid-reverse, calling _shakeController.reverse() on a disposed controller
        // triggers the '_dependents.isEmpty: is not true' framework assertion.
        if (status == AnimationStatus.completed && mounted) {
          _shakeController.reverse();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // FIX: Capture provider reference here (the safe lifecycle hook for InheritedWidget
    // access) using listen: false. This prevents the widget from registering as a
    // dependent, and ensures all async code can safely use _stealthProvider without
    // touching BuildContext after an await gap.
    _stealthProvider ??= Provider.of<StealthProvider>(context, listen: false);
  }

  @override
  void dispose() {
    // FIX: Stop animation before disposing — prevents the status listener from firing
    // on a disposed controller and triggering framework assertions.
    _shakeController.stop();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerErrorShake() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);
    // NOTE: _currentInput is cleared here; callers must NOT issue a second
    // setState for related state resets — use _triggerErrorShakeWithReset() instead.
    setState(() {
      _currentInput.clear();
    });
  }

  void _handleKeyPress(String value) {
    if (_isNavigating) return;
    if (_currentInput.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentInput.add(value);
    });

    if (_currentInput.length == 4) {
      _processCompletedPin(_currentInput.join());
    }
  }

  void _handleBackspace() {
    if (_isNavigating) return;
    if (_currentInput.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentInput.removeLast();
    });
  }

  Future<void> _processCompletedPin(String pin) async {
    if (_isNavigating) return;

    // FIX: Use cached provider reference — never call Provider.of(context) after
    // an async gap. The BuildContext may be stale across awaits and accessing
    // InheritedWidgets then can cause '_dependents.isEmpty' assertion errors.
    final stealthProvider = _stealthProvider;
    if (stealthProvider == null) return;

    // Wait a brief moment to show the filled dot animation before transition
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    if (!stealthProvider.hasPinSet) {
      // ── Setup Mode ────────────────────────────────────────────────────────
      if (!_isConfirming) {
        // First entry completed → move to confirm step
        setState(() {
          _firstEnteredPin = pin;
          _isConfirming = true;
          _currentInput.clear();
        });
      } else {
        // Confirm entry completed
        if (_firstEnteredPin == pin) {
          // PINs match — set guard, stop any animation, then save & navigate
          _isNavigating = true;
          _shakeController.stop();
          await stealthProvider.setPin(pin);
          if (!mounted) return;
          _navigateToNextScreen();
        } else {
          // FIX: Mismatch — consolidate ALL state resets into a single setState
          // call. Previously _triggerErrorShake() issued its own setState and then
          // a second separate setState reset _isConfirming/_firstEnteredPin, causing
          // two rapid rebuilds that could leave the dot-row in an inconsistent state
          // and produce the 8-dot duplication glitch.
          HapticFeedback.heavyImpact();
          _shakeController.forward(from: 0.0);
          setState(() {
            _currentInput.clear();
            _isConfirming = false;
            _firstEnteredPin = "";
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("PINs do not match. Try again."),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      // ── Unlock Mode ───────────────────────────────────────────────────────
      // Set guard before verifyPin which internally calls notifyListeners on success
      _isNavigating = true;
      final success = await stealthProvider.verifyPin(pin);
      if (!mounted) return;
      if (success) {
        // FIX: Stop any ongoing shake animation before navigating away.
        // If a previous wrong-PIN shake is still reversing when the correct PIN
        // succeeds, the animation status listener can fire on a disposed controller
        // during navigation teardown → '_dependents.isEmpty' red-screen assertion.
        _shakeController.stop();
        _navigateToNextScreen();
      } else {
        // Reset guard since we're staying on this screen
        _isNavigating = false;
        _triggerErrorShake();
      }
    }
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    // Use cached provider — avoids any BuildContext dependency after await
    final stealthProvider = _stealthProvider;
    if (stealthProvider == null) return;

    // Check current subscription/trial status
    await stealthProvider.checkSubscriptionStatus();

    if (!mounted) return;

    final isSubscribed = stealthProvider.isSubscribed;
    final isLoggedIn = authToken.isNotEmpty;

    // Check if onboarding is completed
    final bool hasCompletedOnboarding = await SecurePrefs.getBool(
      SecureStorageKeys.PERMISSION,
    );

    if (!mounted) return;

    // Determine target route
    String targetRoute;
    if (isSubscribed) {
      if (!hasCompletedOnboarding) {
        targetRoute = AppRoutes.onboarding;
      } else if (!isLoggedIn) {
        targetRoute = AppRoutes.login;
      } else {
        targetRoute = AppRoutes.tabbar;
      }
    } else if (!isLoggedIn) {
      targetRoute = !hasCompletedOnboarding ? AppRoutes.paywall : AppRoutes.login;
    } else {
      targetRoute = AppRoutes.paywall;
    }

    // Execute navigation after the current frame to avoid framework assertion errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        targetRoute,
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Use the cached provider reference instead of Provider.of(context, listen: false).
    // Calling Provider.of inside build() — even with listen: false — can in some
    // Provider/Flutter versions still associate the element, which combined with rapid
    // animation-driven rebuilds produces the '_dependents.isEmpty' assertion.
    // The fallback handles the edge case where didChangeDependencies hasn't fired yet.
    final stealthProvider =
        _stealthProvider ?? Provider.of<StealthProvider>(context, listen: false);
    final bool hasPinSet = stealthProvider.hasPinSet;

    String instructionText;
    if (!hasPinSet) {
      instructionText = _isConfirming ? "Confirm PIN code" : "Create secure PIN code";
    } else {
      instructionText = "Enter secure PIN code";
    }

    return Scaffold(
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Top Header/Icon
            const Icon(
              Icons.lock_outline,
              size: 56,
              color: Color(0xffFCC604),
            ),
            const SizedBox(height: 24),

            // Instruction Text
            Text(
              instructionText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Camouflage Security Layer",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 40),

            // PIN Dots Indicator — dots are built inside the builder (not as child)
            // so they always reflect the current _currentInput.length on every
            // animation frame rebuild, preventing stale cached dot state.
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, _) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final filled = index < _currentInput.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        height: 16,
                        width: 16,
                        decoration: BoxDecoration(
                          color: filled
                              ? AppColors.appPriSecColor.primaryColor
                              : Colors.white10,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: filled
                                ? AppColors.appPriSecColor.primaryColor
                                : Colors.white24,
                            width: 1.5,
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),

            const Spacer(flex: 2),

            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ["1", "2", "3"].map(_buildKeypadButton).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ["4", "5", "6"].map(_buildKeypadButton).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ["7", "8", "9"].map(_buildKeypadButton).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Space placeholder
                      const SizedBox(width: 64, height: 64),
                      _buildKeypadButton("0"),
                      _buildBackspaceButton(),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String digit) {
    return GestureDetector(
      onTap: () => _handleKeyPress(digit),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 68,
        width: 68,
        decoration: BoxDecoration(
          color: const Color(0xff1e1e1e),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return GestureDetector(
      onTap: _handleBackspace,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 68,
        width: 68,
        decoration: const BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Colors.white70,
            size: 24,
          ),
        ),
      ),
    );
  }
}
