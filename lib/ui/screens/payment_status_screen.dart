import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'purchase_history_screen.dart';

enum PaymentStatus { success, failed, pending }

class PaymentStatusScreen extends StatefulWidget {
  final String productName;
  final String amount;
  final PaymentStatus status;
  final String? errorMessage;
  final String? transactionId; // Add real transaction ID from Razorpay

  const PaymentStatusScreen({
    super.key,
    required this.productName,
    required this.amount,
    required this.status,
    this.errorMessage,
    this.transactionId,
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  int _secondsRemaining = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.status == PaymentStatus.success) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        _redirectToProgress();
      }
    });
  }

  void _redirectToProgress() {
    if (!mounted) return;
    if (widget.status == PaymentStatus.success) {
      // On success: clear the entire stack and land on Purchase History
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PurchaseHistoryScreen()),
        (route) => route.isFirst,
      );
    } else {
      // On failure / pending: just pop back
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSuccess = widget.status == PaymentStatus.success;
    final isFailed = widget.status == PaymentStatus.failed;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60), // Add top margin
              // Animated Status Icon
              _buildStatusIcon(isSuccess, isFailed),
              
              const SizedBox(height: 40),
              
              Text(
                isSuccess 
                  ? 'PAYMENT SUCCESSFUL' 
                  : (isFailed ? 'PAYMENT FAILED' : 'PAYMENT PENDING'),
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isSuccess ? Colors.green : (isFailed ? Colors.red : Colors.orange),
                  letterSpacing: 1,
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
              
              const SizedBox(height: 16),
              
              Text(
                isSuccess 
                  ? 'You have successfully unlocked access to:'
                  : (isFailed ? 'Something went wrong with the transaction.' : 'We are waiting for the payment confirmation.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 500.ms),
              
              const SizedBox(height: 8),
              
              Text(
                widget.productName.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ).animate().fadeIn(delay: 600.ms).scale(),
              
              if (isFailed && widget.errorMessage != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Text(
                    widget.errorMessage!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 40),
              
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.08),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    )
                  ],
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  children: [
                    // Top Section - Status Banner
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.05),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                      child: Center(
                        child: Text(
                          isSuccess ? 'UNLOCKED SUCCESSFULLY' : 'ACTION REQUIRED',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isSuccess ? Colors.green : Colors.red,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(
                            isSuccess ? '₹${widget.amount}' : 'ERROR',
                            style: GoogleFonts.outfit(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black,
                              letterSpacing: -1,
                            ),
                          ).animate().scale(delay: 500.ms),
                          
                          const SizedBox(height: 8),
                          
                          Text(
                            widget.productName.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          const Divider(height: 1, color: Colors.white10),
                          const SizedBox(height: 32),
                          
                          _buildDetailRow('TRANSACTION ID', (widget.transactionId ?? 'CT${DateTime.now().millisecondsSinceEpoch}').toUpperCase(), isDark),
                          const SizedBox(height: 18),
                          _buildDetailRow('PAYMENT METHOD', 'RAZORPAY SECURE', isDark),
                          const SizedBox(height: 18),
                          _buildDetailRow('DATE & TIME', DateTime.now().toString().split('.')[0], isDark),
                          const SizedBox(height: 18),
                          _buildDetailRow('STATUS', isSuccess ? 'COMPLETED' : 'FAILED', isDark, 
                              color: isSuccess ? Colors.green : Colors.red),
                          ],
                        ),
                      ),
                    
                    if (isSuccess) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Redirecting in $_secondsRemaining seconds...',
                              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (isSuccess) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.support_agent_rounded, size: 18, color: AppTheme.primaryGold),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'For support: cbsetoppers@zohomail.in\nWhatsApp: +91 9568902453',
                                  style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey, height: 1.4, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    
                    // Bottom Ticket Edge
                    CustomPaint(
                      size: const Size(double.infinity, 20),
                      painter: _TicketEdgePainter(color: isDark ? const Color(0xFF0F172A) : Colors.white),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 50),
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: _redirectToProgress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSuccess ? AppTheme.primaryGold : (isFailed ? Colors.red.withOpacity(0.1) : Colors.orange),
                    foregroundColor: isSuccess ? Colors.black : (isFailed ? Colors.red : Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: isSuccess ? 12 : 0,
                    shadowColor: AppTheme.primaryGold.withOpacity(0.4),
                  ),
                  child: Text(
                    isSuccess ? 'GET STARTED' : (isFailed ? 'RETRY PAYMENT' : 'CHECK STATUS'),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 15,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool isSuccess, bool isFailed) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: (isSuccess ? Colors.green : (isFailed ? Colors.red : Colors.orange)).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isSuccess ? Icons.check_circle_rounded : (isFailed ? Icons.error_outline_rounded : Icons.hourglass_empty_rounded),
        color: isSuccess ? Colors.green : (isFailed ? Colors.red : Colors.orange),
        size: 100,
      ),
    ).animate().scale(
      duration: 600.ms,
      curve: Curves.elasticOut,
    ).shimmer(
      duration: 2.seconds,
      color: Colors.white24,
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {Color? color}) {
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
        Text(
          value,
          style: GoogleFonts.outfit(
            color: color ?? (isDark ? Colors.white : Colors.black),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TicketEdgePainter extends CustomPainter {
  final Color color;
  _TicketEdgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    const double radius = 10;
    
    // Left Cut
    path.addArc(Rect.fromCircle(center: Offset(0, size.height / 2), radius: radius), -1.57, 3.14);
    // Right Cut
    path.addArc(Rect.fromCircle(center: Offset(size.width, size.height / 2), radius: radius), 1.57, 3.14);
    
    canvas.drawPath(path, paint);
    
    // Dotted line in middle
    final dashPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
      
    double startX = radius + 5;
    while (startX < size.width - radius - 5) {
      canvas.drawLine(Offset(startX, size.height / 2), Offset(startX + 5, size.height / 2), dashPaint);
      startX += 10;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
