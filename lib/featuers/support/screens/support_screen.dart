import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/widgets/global.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'cheetanews@omnilab.co.za',
      queryParameters: {
        'subject': 'CheetaNews Support Request',
      },
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        debugPrint('Could not launch email client');
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
    }
  }

  Future<void> _launchWhatsApp() async {
    final Uri whatsappUri = Uri.parse('https://wa.me/380947115486');
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch WhatsApp');
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(
        backgroundColor: const Color(0xff1e1e1e),
        elevation: 0,
        centerTitle: true,
        leading: Center(
          child: customeBackArrowBalck(
            context,
            color: Colors.white,
          ),
        ),
        title: const Text(
          "Support",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "How can we help?",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Our team is here to assist you. Choose one of the support options below to get in touch with us.",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Email Support Card
              _buildSupportCard(
                context: context,
                icon: Icons.email_outlined,
                iconColor: Colors.blueAccent,
                title: "Email Support",
                subtitle: "cheetanews@omnilab.co.za",
                description: "Send us an email and we will get back to you as soon as possible.",
                onTap: _launchEmail,
              ),

              const SizedBox(height: 20),

              // WhatsApp Support Card
              _buildSupportCard(
                context: context,
                icon: Icons.chat_bubble_outline,
                iconColor: const Color(0xff25D366), // WhatsApp Green
                title: "WhatsApp Support",
                subtitle: "+38 094 711 5486",
                description: "Chat with a support representative directly on WhatsApp.",
                onTap: _launchWhatsApp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xff1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
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
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.appPriSecColor.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
