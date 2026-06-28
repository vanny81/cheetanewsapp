import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/featuers/auth/provider/stealth_provider.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/global.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isInitializingPayment = false;
  final GlobalKey _webViewKey = GlobalKey();
  int _selectedPackageIndex = 0;

  final List<Map<String, dynamic>> _packages = [
    {
      "name": "Standard",
      "price": "ZAR 149",
      "period": "monthly",
      "description": "Perfect for single secure users",
    },
    {
      "name": "Couples",
      "price": "R 199",
      "period": "month",
      "description": "Secure line for you and your partner",
    },
    {
      "name": "Annual (couples)",
      "price": "R 1499",
      "period": "year",
      "description": "Best value for year-round protection",
    },
  ];

  void _verifyAndSyncSubscription(String reference) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            backgroundColor: Color(0xff121212),
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xff00c32b)),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    "Syncing subscription state...",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
    );

    try {
      final apiClient = GetIt.instance<ApiClient>();
      final verifyResponse = await apiClient.request(
        "/payment/verify-transaction",
        method: "POST",
        body: {"reference": reference},
      );

      if (!mounted) return;
      final stealthProvider = Provider.of<StealthProvider>(
        context,
        listen: false,
      );
      await stealthProvider.syncSubscriptionWithBackend();

      if (!mounted) return;
      Navigator.pop(context); // Close the dialog

      if (verifyResponse != null && verifyResponse['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Subscription activated successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        // Check if onboarding is completed
        bool hasCompletedOnboarding = await SecurePrefs.getBool(
          SecureStorageKeys.PERMISSION,
        );

        if (!mounted) return;

        if (!hasCompletedOnboarding) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.onboarding,
            (route) => false,
          );
        } else if (authToken.isEmpty) {
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
      } else {
        _showErrorSnackBar(
          verifyResponse?['error']?.toString() ??
              "Failed to verify transaction.",
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close the dialog
      _showErrorSnackBar("Error verifying payment: $e");
    }
  }

  void _verifyAndSyncSubscriptionMock() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            backgroundColor: Color(0xff121212),
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xff00c32b)),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    "Syncing subscription state...",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    final stealthProvider = Provider.of<StealthProvider>(
      context,
      listen: false,
    );
    await stealthProvider.syncSubscriptionWithBackend();

    if (!mounted) return;
    Navigator.pop(context); // Close the dialog

    if (stealthProvider.isSubscribed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Subscription activated successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      // Check if onboarding is completed
      bool hasCompletedOnboarding = await SecurePrefs.getBool(
        SecureStorageKeys.PERMISSION,
      );

      if (!mounted) return;

      if (!hasCompletedOnboarding) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.onboarding,
          (route) => false,
        );
      } else if (authToken.isEmpty) {
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
    } else {
      _showErrorSnackBar("Verification failed. Please try again.");
    }
  }

  // Real PayStack Checkout WebView Loader
  void _openPaystackGateway(String url) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xff121212),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Secure Mock Checkout",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // WebView
              Expanded(
                child: InAppWebView(
                  key: _webViewKey,
                  initialUrlRequest: URLRequest(url: WebUri(url)),
                  initialSettings: InAppWebViewSettings(
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                  ),
                  onLoadStop: (controller, loadedUrl) {
                    final urlString = loadedUrl?.toString() ?? "";
                    debugPrint("WebView Loaded URL: $urlString");

                    // Detect PayStack success callback/redirection
                    if (urlString.contains("/payment/success") ||
                        urlString.contains("payment-success")) {
                      if (mounted) {
                        Navigator.pop(context); // Close WebView sheet
                        _verifyAndSyncSubscriptionMock();
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      if (!mounted) return;
      // Sync subscription state when webview sheet is closed (just in case they completed but closed early)
      final stealthProvider = Provider.of<StealthProvider>(
        context,
        listen: false,
      );
      stealthProvider.syncSubscriptionWithBackend();
    });
  }

  void _handleContinue() async {
    final isLoggedIn = authToken.isNotEmpty;

    if (!isLoggedIn) {
      // First installation flow -> Go to Onboarding
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.onboarding,
        (route) => false,
      );
    } else {
      // Logged in user with active trial -> Go to Tabbar (or check Onboarding just in case)
      bool hasCompletedOnboarding = await SecurePrefs.getBool(
        SecureStorageKeys.PERMISSION,
      );
      if (!mounted) return;

      if (!hasCompletedOnboarding) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.onboarding,
          (route) => false,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.tabbar,
          (route) => false,
        );
      }
    }
  }

  void _handleRealSubscribe() async {
    setState(() {
      _isInitializingPayment = true;
    });

    try {
      final apiClient = GetIt.instance<ApiClient>();
      final planName =
          _selectedPackageIndex == 0
              ? 'standard'
              : (_selectedPackageIndex == 1 ? 'couples' : 'annual');

      final response = await apiClient.request(
        "/payment/initialize-subscription",
        method: "POST",
        body: {"plan": planName},
      );

      if (!mounted) return;

      setState(() {
        _isInitializingPayment = false;
      });

      if (response != null && response['success'] == true) {
        final data = response['data'];
        final authorizationUrl = data?['authorization_url']?.toString();
        final accessCode = data?['access_code']?.toString();
        final publicKey = data?['publicKey']?.toString();
        final reference = data?['reference']?.toString();

        if (accessCode != null &&
            accessCode.isNotEmpty &&
            publicKey != null &&
            publicKey.isNotEmpty &&
            authorizationUrl != null &&
            !authorizationUrl.contains("mock-checkout")) {
          // Launch real Paystack Flutter SDK
          final priceInKobo =
              _selectedPackageIndex == 0
                  ? 14900
                  : (_selectedPackageIndex == 1 ? 19900 : 149900);

          final userEmail = email.isNotEmpty ? email : "user@cheetanews.com";

          await FlutterPaystackPlus.openPaystackPopup(
            context: context,
            customerEmail: userEmail,
            amount: priceInKobo.toString(),
            reference:
                reference ?? 'ref_${DateTime.now().millisecondsSinceEpoch}',
            publicKey: publicKey,
            authorizationUrl: authorizationUrl,
            onClosed: () {
              debugPrint('Paystack SDK window closed');
            },
            onSuccess: () {
              debugPrint('Paystack SDK payment success!');
              if (reference != null) {
                _verifyAndSyncSubscription(reference);
              }
            },
          );
        } else if (authorizationUrl != null && authorizationUrl.isNotEmpty) {
          // Fallback to webview for mock checkout
          _openPaystackGateway(authorizationUrl);
        } else {
          _showErrorSnackBar("Unable to load checkout gateway.");
        }
      } else {
        _showErrorSnackBar(
          response?['error']?.toString() ?? "Failed to initialize payment.",
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializingPayment = false;
      });
      _showErrorSnackBar("Error initializing payment: $e");
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () {
              // Navigates back to the camouflage layer
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.newsFeed,
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // Paywall Badge/Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.appPriSecColor.primaryColor.withValues(
                    alpha: 0.1,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  size: 64,
                  color: Color(0xffFCC604),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                "Secure Vault Features",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Consumer<StealthProvider>(
                builder: (context, stealthProvider, child) {
                  String statusText = "";
                  Color statusColor = Colors.white;

                  if (authToken.isEmpty) {
                    statusText = "Confirming 3-Day Free Trial";
                    statusColor = Colors.cyanAccent;
                  } else if (stealthProvider.isSubscribed) {
                    statusText = "Subscription Status: Active";
                    statusColor = Colors.greenAccent;
                  } else if (stealthProvider.isTrialActive) {
                    final days = stealthProvider.trialDaysRemaining;
                    statusText =
                        "Subscription Status: Trial Active ($days Days Remaining)";
                    statusColor = Colors.amberAccent;
                  } else {
                    statusText =
                        "Subscription Status: Trial Expired (3-Day Limit)";
                    statusColor = Colors.redAccent;
                  }

                  return Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Feature List
              _buildFeatureRow(
                icon: Icons.security,
                title: "End-to-End Encryption",
                subtitle: "Full privacy protection across all channels.",
              ),
              const SizedBox(height: 20),
              _buildFeatureRow(
                icon: Icons.notifications_off,
                title: "Camouflaged Notifications",
                subtitle: "Real news titles on OS lock screen alerts.",
              ),
              const SizedBox(height: 20),
              _buildFeatureRow(
                icon: Icons.key_sharp,
                title: "PIN Bypass Protection",
                subtitle: "Automated session timers and instant panic locks.",
              ),

              const SizedBox(height: 36),

              Consumer<StealthProvider>(
                builder: (context, stealthProvider, child) {
                  final isLoggedIn = authToken.isNotEmpty;
                  final showContinue =
                      !isLoggedIn || stealthProvider.isTrialActive;

                  if (!showContinue) return const SizedBox.shrink();

                  String btnText =
                      isLoggedIn ? "Continue" : "Start 3-Day Free Trial";

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffFCC604),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: _handleContinue,
                        child: Text(
                          btnText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              Opacity(
                opacity: authToken.isNotEmpty ? 1.0 : 0.5,
                child: AbsorbPointer(
                  absorbing: authToken.isEmpty,
                  child: Column(
                    children: [
                      // Subscription package selector (vibrant visual cards)
                      Column(
                        children: List.generate(_packages.length, (index) {
                          final package = _packages[index];
                          final isSelected = _selectedPackageIndex == index;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPackageIndex = index;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? const Color(
                                          0xff1C281F,
                                        ) // Premium subtle dark green
                                        : const Color(0xff1C1C1E),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? AppColors
                                              .appPriSecColor
                                              .primaryColor
                                          : Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                                boxShadow:
                                    isSelected
                                        ? [
                                          BoxShadow(
                                            color: AppColors
                                                .appPriSecColor
                                                .primaryColor
                                                .withValues(alpha: 0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                        : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? AppColors
                                                    .appPriSecColor
                                                    .primaryColor
                                                : Colors.white38,
                                        width: 2,
                                      ),
                                      color:
                                          isSelected
                                              ? AppColors
                                                  .appPriSecColor
                                                  .primaryColor
                                              : Colors.transparent,
                                    ),
                                    child:
                                        isSelected
                                            ? const Icon(
                                              Icons.check,
                                              size: 12,
                                              color: Colors.black,
                                            )
                                            : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          package['name'],
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                                isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          package['description'],
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        package['price'],
                                        style: TextStyle(
                                          color:
                                              isSelected
                                                  ? AppColors
                                                      .appPriSecColor
                                                      .primaryColor
                                                  : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        "/${package['period']}",
                                        style: const TextStyle(
                                          color: Colors.white30,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 24),

                      // Checkout Action Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppColors.subscriptionGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              "SELECTED PLAN: ${_packages[_selectedPackageIndex]['name'].toUpperCase()}",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _packages[_selectedPackageIndex]['price'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 32,
                                  ),
                                ),
                                Text(
                                  " / ${_packages[_selectedPackageIndex]['period']}",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white24, height: 1),
                            const SizedBox(height: 16),
                            _isInitializingPayment
                                ? const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(
                                        255,
                                        255,
                                        226,
                                        2,
                                      ),
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: _handleRealSubscribe,
                                    child: const Text(
                                      "Activate with Card",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Support Card
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.support);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff1C1C1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.appPriSecColor.primaryColor
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.support_agent,
                          color: AppColors.appPriSecColor.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          "need help? contact support team",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white38),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xff1e1e1e),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Icon(icon, color: const Color(0xffFCC604), size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
