import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';

enum AppInfoType { about, terms }

class AppInfoPage extends StatefulWidget {
  final AppInfoType type;

  const AppInfoPage({super.key, required this.type});

  @override
  State<AppInfoPage> createState() => _AppInfoPageState();
}

class _AppInfoPageState extends State<AppInfoPage> {
  bool get _isAbout => widget.type == AppInfoType.about;

  @override
  Widget build(BuildContext context) {
    final title = _isAbout ? 'About CityVoice India' : 'Terms & Conditions';
    final subtitle = _isAbout
        ? 'Mission, community safety, moderation, and support.'
        : 'Last Updated: June 2026';
    final sections = _isAbout ? _aboutSections : _termsSections;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        itemCount: sections.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _spaced(
              _lazyItem(
                index: 0,
                child: _buildHero(title, subtitle),
              ),
              bottom: 14,
            );
          }

          return _spaced(
            _lazyItem(
              index: index,
              child: _section(sections[index - 1]),
            ),
            bottom: 12,
          );
        },
      ),
    );
  }

  // Adds consistent spacing around lazily built rows.
  Widget _spaced(Widget child, {required double bottom}) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: child,
    );
  }

  // Gives each row a quick fade and slide-in when Flutter builds it.
  Widget _lazyItem({
    required int index,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('${widget.type}-$index'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(
        milliseconds: 280 + (index * 35).clamp(0, 220).toInt(),
      ),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // Builds the branded top card for About and Terms detail pages.
  Widget _buildHero(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E9FF)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/logo.jpeg',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMedium,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Renders one text section with optional bullet points.
  Widget _section(_InfoSection section) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0052D4),
            ),
          ),
          if (section.body != null) ...[
            const SizedBox(height: 8),
            Text(
              section.body!,
              style: _bodyStyle(),
            ),
          ],
          if (section.bullets.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...section.bullets.map(_bullet),
          ],
        ],
      ),
    );
  }

  // Renders a single bullet row with consistent spacing.
  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: Color(0xFF0052D4),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: _bodyStyle(),
            ),
          ),
        ],
      ),
    );
  }

  // Shared paragraph style for all informational copy.
  TextStyle _bodyStyle() {
    return GoogleFonts.inter(
      fontSize: 13,
      color: AppColors.textMedium,
      height: 1.55,
    );
  }

  List<_InfoSection> get _aboutSections => const [
        _InfoSection(
          title: 'Our Mission',
          body:
              'CityVoice India is a citizen engagement platform designed to connect people with their communities by providing a simple and transparent way to report civic issues, share local concerns, and contribute to positive change.\n\nOur mission is to empower citizens by giving them a voice and creating a collaborative environment where community issues can be identified, discussed, and resolved efficiently.',
        ),
        _InfoSection(
          title: 'What We Do',
          body: 'CityVoice India enables users to:',
          bullets: [
            'Report local civic issues and concerns',
            'Share community updates and public information',
            'Engage in constructive discussions',
            'Support transparency and accountability',
            'Contribute to improving neighborhoods and cities',
            'The platform serves as a bridge between citizens, communities, and stakeholders by facilitating responsible communication and awareness.',
          ],
        ),
        _InfoSection(
          title: 'Community First',
          body:
              'We believe that every citizen deserves a safe and respectful platform to express concerns and participate in community development.\n\nTo maintain a positive environment, CityVoice India enforces community guidelines and moderation policies that prohibit:',
          bullets: [
            'Harassment and bullying',
            'Hate speech',
            'False or misleading information',
            'Illegal activities',
            'Offensive or abusive content',
          ],
        ),
        _InfoSection(
          title: 'Safety and Moderation',
          body:
              'CityVoice India is committed to maintaining a safe platform for all users.\n\nWe provide:',
          bullets: [
            'Content reporting mechanisms',
            'User blocking functionality',
            'Content moderation and review',
            'Community guidelines enforcement',
            'Account suspension for policy violations',
            'Our moderation team reviews reports and takes appropriate action against content or accounts that violate our policies.',
          ],
        ),
        _InfoSection(
          title: 'Our Vision',
          body:
              'We envision a future where technology empowers citizens to actively participate in improving their communities through transparent communication, responsible reporting, and collective action.',
        ),
        _InfoSection(
          title: 'Contact Us',
          body:
              'For support, feedback, or inquiries:\n\nCityVoice India\nEmail: cityvoiceofficial@gmail.com',
        ),
      ];

  List<_InfoSection> get _termsSections => const [
        _InfoSection(
          title: 'Welcome',
          body:
              'Welcome to CityVoice India. By creating an account, accessing, or using the application, you agree to comply with these Terms of Use.',
        ),
        _InfoSection(
          title: '1. Acceptance of Terms',
          body:
              'By registering for or using CityVoice India, you acknowledge that you have read, understood, and agree to be bound by these Terms of Use and our Privacy Policy.\n\nIf you do not agree with these terms, you must not use the application.',
        ),
        _InfoSection(
          title: '2. Purpose of the Platform',
          body:
              'CityVoice India is a community platform that enables users to share civic concerns, public issues, local updates, and community-related information.\n\nUsers are solely responsible for the content they submit, post, upload, or share through the platform.',
        ),
        _InfoSection(
          title: '3. User Conduct',
          body: 'Users agree not to:',
          bullets: [
            'Post false, misleading, or fraudulent information.',
            'Publish content that is defamatory, abusive, threatening, harassing, hateful, or discriminatory.',
            'Upload obscene, sexually explicit, violent, or illegal content.',
            'Impersonate any person, organization, or government authority.',
            'Violate the privacy rights of others.',
            'Share copyrighted content without authorization.',
            'Engage in spam, scams, or malicious activities.',
          ],
        ),
        _InfoSection(
          title: '4. Community Guidelines',
          body:
              'All users must maintain respectful behavior.\n\nThe following content is strictly prohibited:',
          bullets: [
            'Hate speech',
            'Harassment or bullying',
            'Threats of violence',
            'Graphic or disturbing content',
            'Sexually explicit material',
            'Illegal activities',
            'Misinformation intended to cause harm',
            'Content promoting discrimination',
            'Violation of these guidelines may result in content removal or account suspension.',
          ],
        ),
        _InfoSection(
          title: '5. Reporting and Blocking',
          body: 'CityVoice India provides mechanisms that allow users to:',
          bullets: [
            'Report objectionable content',
            'Report abusive users',
            'Block users from interacting with them',
            'Reports are reviewed by moderators and administrators.',
            'Users are encouraged to report content that violates these Terms or Community Guidelines.',
          ],
        ),
        _InfoSection(
          title: '6. Content Moderation',
          body: 'CityVoice India reserves the right to:',
          bullets: [
            'Review reported content',
            'Remove content that violates these Terms',
            'Suspend or permanently ban offending users',
            'Restrict access to platform features',
            'Reported violations may be reviewed and acted upon within 24 hours where reasonably possible.',
          ],
        ),
        _InfoSection(
          title: '7. User Responsibility',
          body:
              'You are solely responsible for all content posted from your account.\n\nCityVoice India does not guarantee the accuracy, completeness, or reliability of user-generated content.',
        ),
        _InfoSection(
          title: '8. Account Suspension and Termination',
          body: 'We may suspend or terminate accounts that:',
          bullets: [
            'Violate these Terms',
            'Repeatedly receive valid abuse reports',
            'Engage in harmful or illegal activities',
            'Attempt to misuse the platform',
          ],
        ),
        _InfoSection(
          title: '9. Privacy',
          body:
              'Your use of CityVoice India is subject to our Privacy Policy, which explains how we collect, use, and protect your information.',
        ),
        _InfoSection(
          title: '10. Limitation of Liability',
          body:
              'CityVoice India shall not be liable for any damages arising from user-generated content or the actions of other users.\n\nUsers access and use the platform at their own risk.',
        ),
        _InfoSection(
          title: '11. Changes to These Terms',
          body:
              'We may update these Terms from time to time.\n\nContinued use of the application after updates constitutes acceptance of the revised Terms.',
        ),
        _InfoSection(
          title: '12. Contact Us',
          body:
              'For questions, reports, or concerns regarding these Terms:\n\nCityVoice India Support\nEmail: cityvoiceofficial@gmail.com',
        ),
      ];
}

class _InfoSection {
  final String title;
  final String? body;
  final List<String> bullets;

  const _InfoSection({
    required this.title,
    this.body,
    this.bullets = const [],
  });
}
