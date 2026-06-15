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
        if (status == AnimationStatus.completed) {
          _shakeController.reverse();
        }
      });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerErrorShake() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);
    setState(() {
      _currentInput.clear();
    });
  }

  void _handleKeyPress(String value) {
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
    if (_currentInput.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentInput.removeLast();
    });
  }

  Future<void> _processCompletedPin(String pin) async {
    final stealthProvider = Provider.of<StealthProvider>(context, listen: false);

    // Wait a brief millisecond to show the filled dot animation before transition
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    if (!stealthProvider.hasPinSet) {
      // Setup Mode
      if (!_isConfirming) {
        // First entry completed
        setState(() {
          _firstEnteredPin = pin;
          _isConfirming = true;
          _currentInput.clear();
        });
      } else {
        // Confirm entry completed
        if (_firstEnteredPin == pin) {
          // Success! PIN codes match
          await stealthProvider.setPin(pin);
          _navigateToNextScreen();
        } else {
          // Mismatch
          _triggerErrorShake();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("PINs do not match. Try again."),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 2),
            ),
          );
          setState(() {
            _isConfirming = false;
            _firstEnteredPin = "";
          });
        }
      }
    } else {
      // Unlock Mode
      final success = await stealthProvider.verifyPin(pin);
      if (success) {
        _navigateToNextScreen();
      } else {
        _triggerErrorShake();
      }
    }
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;
    final stealthProvider = Provider.of<StealthProvider>(context, listen: false);
    
    // Check current subscription/trial status
    await stealthProvider.checkSubscriptionStatus();

    if (!mounted) return;

    final isSubscribed = stealthProvider.isSubscribed;
    final isLoggedIn = authToken.isNotEmpty;

    // Check if onboarding is completed
    bool hasCompletedOnboarding = await SecurePrefs.getBool(
      SecureStorageKeys.PERMISSION,
    );

    if (!mounted) return;

    // SCENARIO #3: Active subscription exists -> skip Paywall
    if (isSubscribed) {
      if (!hasCompletedOnboarding) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.onboarding,
          (route) => false,
        );
      } else if (!isLoggedIn) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.tabbar,
          (route) => false,
        );
      }
      return;
    }

    // User is NOT subscribed (could be on active trial, expired trial, or first installation flow)
    if (!isLoggedIn) {
      // First installation flow: PIN -> Paywall (Start Free Trial) -> Onboarding -> Login -> Tabbar
      if (!hasCompletedOnboarding) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.paywall,
          (route) => false,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    } else {
      // Logged in user with active trial (Scenario #1) or expired trial (Scenario #2)
      // Both route to Paywall (Paywall screen dynamically renders a "Continue" button or locks screen)
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.paywall,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stealthProvider = Provider.of<StealthProvider>(context);
    final bool hasPinSet = stealthProvider.hasPinSet;

    String instructionText = "";
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

            // PIN Dots Indicator
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Padding(
                  padding: EdgeInsets.only(left: _shakeAnimation.value, right: -_shakeAnimation.value),
                  child: child,
                );
              },
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
                      color: filled ? AppColors.appPriSecColor.primaryColor : Colors.white10,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: filled ? AppColors.appPriSecColor.primaryColor : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
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
                      // Space placeholder or extra button
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
