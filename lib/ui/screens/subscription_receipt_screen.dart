import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class SubscriptionReceiptScreen extends StatelessWidget {
  final String receiptNumber;
  final String planName;
  final String amount;
  final String transactionId;
  final String purchaseDate;
  final String validUntil;

  const SubscriptionReceiptScreen({
    super.key,
    required this.receiptNumber,
    required this.planName,
    required this.amount,
    required this.transactionId,
    required this.purchaseDate,
    required this.validUntil,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        title: Text(
          'RECEIPT',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.primaryGold.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGold.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryGold.withOpacity(0.2),
                          AppTheme.primaryGold.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 60,
                        ).animate().scale(curve: Curves.elasticOut),
                        const SizedBox(height: 16),
                        Text(
                          'PAYMENT SUCCESSFUL',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.green,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your subscription has been activated!',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildLogo(isDark),
                        const SizedBox(height: 24),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 24),
                        _buildDetailRow('RECEIPT NO.', receiptNumber, isDark),
                        const SizedBox(height: 16),
                        _buildDetailRow('PLAN', '$planName Subscription'.toUpperCase(), isDark),
                        const SizedBox(height: 16),
                        _buildDetailRow('AMOUNT PAID', '₹$amount', isDark, valueColor: Colors.green),
                        const SizedBox(height: 16),
                        _buildDetailRow('TRANSACTION ID', transactionId.isNotEmpty ? transactionId : 'N/A', isDark),
                        const SizedBox(height: 16),
                        _buildDetailRow('DATE', _formatDate(purchaseDate), isDark),
                        const SizedBox(height: 16),
                        _buildDetailRow('VALID UNTIL', _formatDate(validUntil), isDark, valueColor: Colors.orange),
                        const SizedBox(height: 16),
                        _buildDetailRow('STATUS', 'ACTIVE', isDark, valueColor: Colors.green),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, color: AppTheme.primaryGold, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                '$planName Plan Activated',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryGold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.support_agent_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Need help? cbsetoppers@zohomail.in',
                            style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: AppTheme.primaryGold.withOpacity(0.4),
                ),
                child: Text(
                  'DONE',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {},
              child: Text(
                'Download Receipt',
                style: GoogleFonts.outfit(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryGold.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.school_rounded,
            color: AppTheme.primaryGold,
            size: 40,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'CBSE TOPPERS',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'cbsetoppers.com',
          style: GoogleFonts.outfit(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.grey.shade500,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(
              color: valueColor ?? (isDark ? Colors.white : Colors.black),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return isoDate;
    }
  }
}
