import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppTheme.textHeadingColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'LEGAL & ABOUT',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppTheme.textHeadingColor,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            _buildHero(isDark),
            const SizedBox(height: 32),
            _buildLegalSections(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(bool isDark) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Image.asset('assets/logo.png', fit: BoxFit.cover),
          ),
        ),
        SizedBox(height: 16),
        Text(
          'T0PPERS 24/7',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppTheme.textHeadingColor,
            letterSpacing: -1,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Version 2.0.0 (2026 Edition)',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryColor,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'T0PPERS 24/7 IS A PREMIUM EDUCATIONAL PLATFORM DESIGNED TO EMPOWER STUDENTS WITH AI-DRIVEN LEARNING TOOLS, COMPETITIVE EXAM PREPARATION, AND REAL-TIME PERFORMANCE ANALYTICS. OUR MISSION IS TO DEMOCRATIZE HIGH-QUALITY EDUCATION THROUGH TECHNOLOGY.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.grey[700],
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildLegalSections(BuildContext context, bool isDark) {
    final border = isDark ? Colors.white12 : Colors.grey.shade200;
    final cardBg = isDark ? Colors.white.withOpacity(0.04) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: border),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildPolicySection(
                'Privacy Policy',
                'Effective Date: March 2025\n'
                    'Platform: T0PPERS 24/7 Website & App\n'
                    'Sub-Units: CBSE T0PPERS (IX, X, XI, XII) | CUET T0PPERS | NEET T0PPERS | JEE T0PPERS\n\n'
                    '1. INTRODUCTION\n'
                    'T0PPERS 24/7 ("we", "our", "us") is committed to protecting the privacy and personal data of all users. This Privacy Policy explains how we collect, use, store, and protect your personal information when you use our platform and its sub-units including CBSE T0PPERS, CUET T0PPERS, NEET T0PPERS, and JEE T0PPERS. By using our services or purchasing from the T0PPERS STORE, you agree to these terms.\n\n'
                    '2. INFORMATION WE COLLECT\n'
                    '• Personal Information: Full name, Email address, Phone number, Billing address, and Class/Grade/Target Examination.\n'
                    '• Usage Data: Device type, browser type, IP address, approximate location, pages visited, and session duration.\n'
                    '• Store Data: Purchase history, PDF access/download activity, and delivery email address.\n\n'
                    '3. HOW WE USE YOUR INFORMATION\n'
                    'We use your data to deliver purchased PDFs and receipts, manage accounts, process transactions, send important academic updates, and improve user experience.\n\n'
                    '4. DATA SHARING\n'
                    'We do not sell your data. We share information ONLY with: payment gateways (Razorpay/Paytm), email providers (Zoho Mail for PDF delivery), and legal authorities if required by law.\n\n'
                    '5. SECURITY\n'
                    'We use SSL/TLS encryption, secure databases, and restricted access protocols. While we use stringent practices, no electronic storage is 100% secure.\n\n'
                    '6. STORE ACCESS\n'
                    'Upon purchase, PDFs are sent to your email and granted access within the App. We are not responsible for incorrect email addresses provided.\n\n'
                    '7. YOUR RIGHTS\n'
                    'You have the right to access, correct, or delete your data. Contact us at: cbsetoppers@zohomail.in | WhatsApp: +919568902453\n\n'
                    '© 2026 T0PPERS 24/7 | All Rights Reserved',
                Icons.privacy_tip_outlined,
                Colors.blue,
                isDark,
              ),
              Divider(color: border, height: 1),
              _buildPolicySection(
                'Terms & Conditions',
                'Effective Date: March 2025\n'
                    'Platform: T0PPERS 24/7 Website & App\n'
                    'Sub-Units: CBSE T0PPERS (IX-XII) | CUET T0PPERS | NEET T0PPERS | JEE T0PPERS\n\n'
                    '1. ACCEPTANCE\n'
                    'By using the T0PPERS 24/7 platform or purchasing from the T0PPERS STORE, you agree to these Terms. If you do not agree, please discontinue use immediately.\n\n'
                    '2. PLATFORM DESCRIPTION\n'
                    'T0PPERS 24/7 provides digital study materials for students preparing for CBSE, CUET, NEET, and JEE exams. Materials are delivered in PDF format via email and accessed via the App.\n\n'
                    '3. ELIGIBILITY\n'
                    'Users must be 13+ or use the platform under parental supervision. You are responsible for account confidentiality.\n\n'
                    '4. INTELLECTUAL PROPERTY\n'
                    'All PDFs, notes, and content are the exclusive property of T0PPERS 24/7. Materials are for personal, non-commercial use only. Redistribution, resale, or piracy will result in immediate termination and legal action.\n\n'
                    '5. PURCHASE & DELIVERY\n'
                    'Payments are secure. Upon purchase, PDFs are sent via email and activated in-app. We are not liable for non-receipt due to incorrect user details.\n\n'
                    '6. DISCLAIMER\n'
                    'While we strive for accuracy, we do not guarantee specific academic results. We are not officially affiliated with CBSE, NTA, or any other board.\n\n'
                    '7. GOVERNING LAW\n'
                    'Terms are governed by Indian law. Disputes are subject to the exclusive jurisdiction of courts in Agra, Uttar Pradesh, India.\n\n'
                    '© 2026 T0PPERS 24/7 | All Rights Reserved',
                Icons.description_outlined,
                Colors.orange,
                isDark,
              ),
              Divider(color: border, height: 1),
              _buildPolicySection(
                'Cancellation & Refund Policy',
                'Effective Date: March 2025\n'
                    'Platform: T0PPERS 24/7 Website & App\n'
                    'Sub-Units: CBSE T0PPERS (IX-XII) | CUET T0PPERS | NEET T0PPERS | JEE T0PPERS\n\n'
                    '1. OVERVIEW\n'
                    'At T0PPERS 24/7, we are committed to high-quality digital study materials. Since all products (PDFs) are delivered instantly, we maintain a strict policy regarding cancellations and refunds.\n\n'
                    '2. CANCELLATION\n'
                    '• Before Payment: You may cancel anytime before completing the payment.\n'
                    '• After Payment: Once confirmed and delivered (Email/In-App), cancellation is NOT possible due to the digital nature of the content.\n\n'
                    '3. REFUND POLICY\n'
                    '• Non-Refundable: Once delivered/activated, accidental purchases, wrong class selection, or dissatisfaction with content are not eligible for a refund.\n'
                    '• Eligible Scenarios: Refunds/replacements are considered only if the file is corrupted/empty or multiple charges occurred for the same product due to a technical error. Contact support within 48 hours.\n\n'
                    '4. PROCESSING\n'
                    'Approved refunds are credited back to the original payment method within 5-7 business days. T0PPERS 24/7 reserves the right to make the final decision.\n\n'
                    '© 2026 T0PPERS 24/7 | All Rights Reserved',
                Icons.assignment_return_outlined,
                Colors.red,
                isDark,
              ),
              Divider(color: border, height: 1),
              _buildPolicySection(
                'Study Content Delivery Policy',
                'Effective Date: March 2025\n'
                    'Platform: T0PPERS 24/7 Website & App\n'
                    'Sub-Units: CBSE T0PPERS (IX-XII) | CUET T0PPERS | NEET T0PPERS | JEE T0PPERS\n\n'
                    '1. INTRODUCTION\n'
                    'This policy governs the process by which T0PPERS 24/7 delivers purchased study materials. All materials are digital (PDF format) and delivered electronically. No physical delivery is provided.\n\n'
                    '2. MODE OF DELIVERY\n'
                    '• Email Delivery: Purchased PDFs and receipts are sent to your provided or registered email address upon payment.\n'
                    '• In-App Access: Access is activated inside your account on the T0PPERS 24/7 App instantly or within 30 minutes.\n\n'
                    '3. DELIVERY ISSUES\n'
                    'If you do not receive the PDF within 30 minutes, please check your spam/junk folder. For incorrect email addresses or in-app access issues, contact support immediately with your order ID.\n\n'
                    '4. RE-DELIVERY\n'
                    'Free re-delivery is provided only for platform-side errors or corrupted files. Requests must be made within 7 days of purchase.\n\n'
                    '5. RESTRICTIONS\n'
                    'PDFs are for personal use only. Sharing, forwarding, or redistributing content to third parties is strictly prohibited and subject to legal action.\n\n'
                    '© 2026 T0PPERS 24/7 | All Rights Reserved',
                Icons.local_shipping_outlined,
                Colors.green,
                isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPolicySection(
    String title,
    String content,
    IconData icon,
    Color iconColor,
    bool isDark,
  ) {
    return Theme(
      data: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
      ).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        iconColor: AppTheme.primaryColor,
        collapsedIconColor: Colors.grey,
        title: Text(
          title.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppTheme.textHeadingColor,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              content,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }
}
