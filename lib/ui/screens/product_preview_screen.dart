import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as enc;
import 'payment_status_screen.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/purchase_history_provider.dart';
import '../../models/store_product_model.dart';
import '../../providers/supabase_provider.dart';
import '../../models/pdf_file_model.dart';
import '../../core/utils/pdf_utils.dart';
import '../../widgets/pdf_download_dialog.dart';

class ProductPreviewScreen extends ConsumerStatefulWidget {
  final StoreProductModel product;

  const ProductPreviewScreen({super.key, required this.product});

  @override
  ConsumerState<ProductPreviewScreen> createState() =>
      _ProductPreviewScreenState();
}

class _ProductPreviewScreenState extends ConsumerState<ProductPreviewScreen> {
  late Razorpay _razorpay;
  bool _isProcessing = false;

  // Storing encrypted live keys directly in the frontend inside secured form
  static const String _encryptedKeyId =
      "jW4sPZCZIVU+i1d2GrhcnwAHFx4w3tFEDivgbo0vyG0=";
  // static const String _encryptedKeySecret = "UHsN0PNUL0FOohhNoxD/qDEnwxe3vCOBqc0PcIQ6o7w="; // Stored securely if ever needed

  String _getDecryptedKeyId() {
    final key = enc.Key.fromUtf8('T0PPERS247_SECURE_KEYS_ENCRYPTIO');
    final iv = enc.IV.fromUtf8('T0PPERS247_SEC_I');
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(_encryptedKeyId, iv: iv);
  }

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() {
      _isProcessing = false;
    });
    final orderId = response.orderId ?? 'ORD_${Random().nextInt(999999)}';

    try {
      await ref
          .read(purchaseHistoryProvider.notifier)
          .addPurchase(
            id: orderId,
            productName: widget.product.name,
            productCode: widget.product.id,
            amount: widget.product.sellingPrice.toInt().toString(),
            fileUrl: widget.product.fileUrl,
          );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentStatusScreen(
              productName: widget.product.name,
              amount: widget.product.sellingPrice.toInt().toString(),
              status: PaymentStatus.success,
              transactionId: response.paymentId,
            ),
          ),
        );
      }
    } catch (e) {
      // Navigate to status screen with error if saving failed (likely a DB issue)
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentStatusScreen(
              productName: widget.product.name,
              amount: widget.product.sellingPrice.toInt().toString(),
              status: PaymentStatus.failed,
              transactionId: response.paymentId,
              errorMessage:
                  "Payment succeeded but could not be saved to your history. Please contact support with Payment ID: ${response.paymentId}\nError: $e",
            ),
          ),
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() {
      _isProcessing = false;
    });

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentStatusScreen(
            productName: widget.product.name,
            amount: widget.product.sellingPrice.toInt().toString(),
            status: PaymentStatus.failed,
            errorMessage:
                response.message ?? "Transaction cancelled or failed.",
          ),
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() {
      _isProcessing = false;
    });

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentStatusScreen(
            productName: widget.product.name,
            amount: widget.product.sellingPrice.toInt().toString(),
            status: PaymentStatus.pending,
          ),
        ),
      );
    }
  }

  void _startPayment() {
    setState(() {
      _isProcessing = true;
    });
    var options = {
      'key': _getDecryptedKeyId(),
      'amount': (widget.product.sellingPrice * 100).toInt(), // Amount in paise
      'name': 'T0PPERS 24/7',
      'description': 'Purchase: ${widget.product.name}',
      'prefill': {'contact': '9568902453', 'email': 'cbsetoppers@zohomail.in'},
      'external': {
        'wallets': ['paytm'],
      },
      'theme': {
        'color': '#FFD700', // Golden
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.product.name;
    final category = widget.product.category ?? 'PREMIUM';
    String? iconUrl = widget.product.imageUrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      bottomNavigationBar: Container(
        height: 120,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0),
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
              Theme.of(context).scaffoldBackgroundColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL PRICE',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '₹${widget.product.sellingPrice.toInt()}',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Consumer(
                  builder: (context, ref, child) {
                    final history = ref.watch(purchaseHistoryProvider);
                    final isPurchased = history.any(
                      (p) => p['code'] == widget.product.id,
                    );

                    return Container(
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: isPurchased
                            ? []
                            : [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                      ),
                      child:
                          ElevatedButton(
                                onPressed: (isPurchased || _isProcessing)
                                    ? null
                                    : _startPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isPurchased
                                      ? Colors.green.withOpacity(0.1)
                                      : AppTheme.primaryColor,
                                  foregroundColor: isPurchased
                                      ? Colors.green
                                      : Colors.black,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isProcessing
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.black,
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : Text(
                                        isPurchased
                                            ? 'ALREADY UNLOCKED'
                                            : 'BUY',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              )
                              .animate(
                                onPlay: (controller) =>
                                    controller.repeat(reverse: true),
                              )
                              .shimmer(
                                duration: 2.seconds,
                                color: Colors.white.withOpacity(
                                  isPurchased ? 0 : 0.3,
                                ),
                              ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 450,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.4),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: isDark ? Colors.black : Colors.white,
                    child: Builder(
                      builder: (context) {
                        final allImages = [
                          if (widget.product.imageUrl != null &&
                              widget.product.imageUrl!.isNotEmpty)
                            widget.product.imageUrl!,
                          ...(widget.product.imageUrls ?? []),
                        ];

                        if (allImages.isNotEmpty) {
                          return PageView.builder(
                            itemCount: allImages.length,
                            itemBuilder: (context, index) {
                              final url = allImages[index];
                              return Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Center(
                                  child: Icon(
                                    Icons.shopping_bag,
                                    color: AppTheme.primaryColor,
                                    size: 80,
                                  ),
                                ),
                              );
                            },
                          );
                        }

                        return Center(
                          child: (iconUrl != null && iconUrl.isNotEmpty)
                              ? (iconUrl.startsWith('http')
                                    ? Image.network(
                                        iconUrl,
                                        width: 200,
                                        height: 200,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => Icon(
                                          Icons.shopping_bag,
                                          color: AppTheme.primaryColor,
                                          size: 100,
                                        ),
                                      )
                                    : Image.asset(
                                        iconUrl,
                                        width: 200,
                                        height: 200,
                                        errorBuilder: (_, _, _) => Icon(
                                          Icons.shopping_bag,
                                          color: AppTheme.primaryColor,
                                          size: 100,
                                        ),
                                      ))
                              : Icon(
                                  Icons.shopping_bag_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 150,
                                ),
                        );
                      },
                    ),
                  ),
                  // Bottom Gradient for text readability
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0),
                            Colors.black.withOpacity(0.8),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  if (widget.product.previewUrl != null &&
                      widget.product.previewUrl!.isNotEmpty)
                    Positioned(
                      bottom: 30,
                      right: 20,
                      child: GestureDetector(
                        onTap: () {
                          final pdfUrl = widget.product.previewUrl!;
                          final driveId = PdfUtils.extractDriveId(pdfUrl);
                          PdfDownloadDialog.show(
                            context,
                            PdfFileModel(
                              id: widget.product.id,
                              name: '${widget.product.name} - Preview',
                              driveFileId: driveId,
                              url: driveId == null ? pdfUrl : null,
                              subject: 'Topper Store',
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'PREVIEW PDF',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              transform: Matrix4.translationValues(0, -40, 0),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    name.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppTheme.textHeadingColor,
                      height: 1.1,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Category tag as suffix after product name
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...category.split(',').map((tag) {
                        final t = tag.trim();
                        if (t.isEmpty) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.18),
                                AppTheme.secondaryColor.withOpacity(0.10),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.35),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '# ${t.toUpperCase()}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                              letterSpacing: 1,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.02)
                          : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SPECIFICATIONS',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSpecRow(
                          Icons.description_outlined,
                          'File Format',
                          'Premium PDF Vault',
                          isDark,
                        ),
                        _buildSpecRow(
                          Icons.file_download_outlined,
                          'Delivery',
                          'Instant Access',
                          isDark,
                        ),
                        _buildSpecRow(
                          Icons.devices_rounded,
                          'Access',
                          'Mobile & Desktop',
                          isDark,
                        ),
                        if (widget.product.edition != null)
                          _buildSpecRow(
                            Icons.history_edu_rounded,
                            'Edition',
                            widget.product.edition!,
                            isDark,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                  Text(
                    'OVERVIEW',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.product.description ??
                        'Prepare better with CBSE TOPPERS. This premium package is designed by experts to help you master $name with ease. Get access to the most high-yield content available.',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.8,
                    ),
                  ),

                  const SizedBox(height: 40),
                  _buildFeatureItem(
                    Icons.auto_fix_high_rounded,
                    'AI-Integrated Prep',
                    'Get personalized suggestions based on your weak points.',
                    isDark,
                  ),
                  _buildFeatureItem(
                    Icons.workspace_premium_rounded,
                    'T0PPER Verified',
                    'Content verified by rank holders and expert educators.',
                    isDark,
                  ),

                  // ─── FAQ Section ─────────────────────────────────────────
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'FREQUENTLY ASKED QUESTIONS',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade200,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildFAQTile(
                          'Is this a physical book or a PDF?',
                          'This is a digital product. You will get instant access to the PDF vault once the payment is successful.',
                          isDark,
                        ),
                        _buildFAQTile(
                          'Can I print these notes?',
                          'Yes, you can easily download and print the PDFs for your offline study convenience.',
                          isDark,
                        ),
                        _buildFAQTile(
                          'How do I access my purchase?',
                          'After purchase, go to Account > Purchase History. You can view all your unlocked content there.',
                          isDark,
                        ),
                      ],
                    ),
                  ),

                  // ─── Policies Section ────────────────────────────────────
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'POLICIES & LEGAL',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade200,
                      ),
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
                        _buildPolicyTile(
                          'Study Content Delivery Policy',
                          Icons.local_shipping_outlined,
                          Colors.green,
                          isDark,
                          'Effective Date: March 2025\n'
                              'Platform: T0PPERS 24/7 Website & App\n\n'
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
                        ),
                        Divider(
                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                          height: 1,
                        ),
                        _buildPolicyTile(
                          'Cancellation & Refund Policy',
                          Icons.assignment_return_outlined,
                          Colors.red,
                          isDark,
                          'Effective Date: March 2025\n'
                              'Platform: T0PPERS 24/7 Website & App\n\n'
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
                        ),
                        Divider(
                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                          height: 1,
                        ),
                        _buildPolicyTile(
                          'Terms & Conditions',
                          Icons.description_outlined,
                          Colors.orange,
                          isDark,
                          'Effective Date: March 2025\n'
                              'Platform: T0PPERS 24/7 Website & App\n\n'
                              '1. ACCEPTANCE\n'
                              'By purchasing from the T0PPERS STORE, you agree to these Terms. If you do not agree, please discontinue use immediately.\n\n'
                              '2. PLATFORM DESCRIPTION\n'
                              'T0PPERS 24/7 provides digital study materials for students preparing for CBSE, CUET, NEET, and JEE exams. Materials are delivered in PDF format via email and accessed via the App.\n\n'
                              '3. ELIGIBILITY\n'
                              'Users must be 13+ or use the platform under parental supervision. You are responsible for account confidentiality.\n\n'
                              '4. INTELLECTUAL PROPERTY\n'
                              'All PDFs, notes, and content are the exclusive property of T0PPERS 24/7. Materials are for personal, non-commercial use only. Redistribution, resale, or piracy will result in immediate termination and legal action.\n\n'
                              '5. PURCHASE & DELIVERY\n'
                              'Payments are secure. Upon purchase, PDFs are sent via email and activated in‑app. We are not liable for non-receipt due to incorrect user details.\n\n'
                              '6. DISCLAIMER\n'
                              'While we strive for accuracy, we do not guarantee specific academic results. We are not officially affiliated with CBSE, NTA, or any other board.\n\n'
                              '7. GOVERNING LAW\n'
                              'Terms are governed by Indian law. Disputes are subject to the exclusive jurisdiction of courts in Agra, Uttar Pradesh, India.\n\n'
                              '© 2026 T0PPERS 24/7 | All Rights Reserved',
                        ),
                      ],
                    ),
                  ),

                  // ─── Explore More Section ────────────────────────────────
                  const SizedBox(height: 48),
                  Consumer(
                    builder: (context, ref, child) {
                      final productsAsync = ref.watch(storeProductsProvider);
                      return productsAsync.when(
                        data: (products) {
                          final currentCat =
                              widget.product.category?.toUpperCase() ?? '';
                          final currentTags = currentCat
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();

                          final relatedMatch = products.where((p) {
                            if (p.id == widget.product.id) return false;
                            final pCat = p.category?.toUpperCase() ?? '';
                            final pTags = pCat
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty);
                            // Simple overlap check
                            return currentTags.any(
                                  (tag) => pTags.contains(tag),
                                ) ||
                                (currentTags.isEmpty && pTags.isEmpty);
                          }).toList();

                          if (relatedMatch.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'EXPLORE MORE',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.grey.shade500,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 260,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: relatedMatch.length,
                                  itemBuilder: (context, index) {
                                    final p = relatedMatch[index];
                                    return _buildRelatedProductCard(p, isDark);
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                  // Support nudge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.support_agent_rounded,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Questions? Contact us at cbsetoppers@zohomail.in or WhatsApp +91 9568902453',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                              height: 1.4,
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
        ],
      ),
    );
  }

  Widget _buildSpecRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 16),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    IconData icon,
    String title,
    String subtitle,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTile(String question, String answer, bool isDark) {
    return Theme(
      data: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
      ).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          question.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppTheme.textHeadingColor,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Text(
            answer,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.grey[600],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyTile(
    String title,
    IconData icon,
    Color iconColor,
    bool isDark,
    String content,
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
            fontSize: 13,
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
                height: 1.55,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedProductCard(StoreProductModel p, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductPreviewScreen(product: p)),
        );
      },
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 20, bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: isDark ? Colors.black26 : Colors.grey.shade50,
                child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                    ? Image.network(
                        p.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.auto_stories_rounded,
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          size: 40,
                        ),
                      )
                    : Icon(
                        Icons.auto_stories_rounded,
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        size: 40,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppTheme.textHeadingColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${p.sellingPrice.toInt()}',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
