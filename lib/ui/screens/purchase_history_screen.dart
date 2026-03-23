import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/purchase_history_provider.dart';
import '../../services/platform_helper.dart';
import '../../models/pdf_file_model.dart';
import '../../core/utils/pdf_utils.dart';
import '../../widgets/pdf_download_dialog.dart';
import 'subscription_receipt_screen.dart';


class PurchaseHistoryScreen extends ConsumerWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(purchaseHistoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('PURCHASE HISTORY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: history.isEmpty
          ? Center(
              child: Text(
                'NO PURCHASES YET',
                style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final purchase = history[index];
                final isSubscription = purchase['type'] == 'subscription';
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSubscription 
                          ? AppTheme.primaryGold.withOpacity(0.5)
                          : (isDark ? Colors.white10 : Colors.grey.shade200),
                      width: isSubscription ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              if (isSubscription)
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGold.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.stars_rounded, size: 16, color: AppTheme.primaryGold),
                                ),
                              Expanded(
                                child: Text(
                                  purchase['name'].toString().toUpperCase(),
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '₹${purchase['amount']}',
                            style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (isSubscription && purchase['receiptNumber'] != null)
                        Text('Receipt No: ${purchase['receiptNumber']}', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade400)),
                      if (!isSubscription)
                        Text('Order ID: ${purchase['id']}', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateTime.parse(purchase['date']).toLocal().toString().split('.')[0],
                                style: GoogleFonts.outfit(fontSize: 12),
                              ),
                              if (isSubscription && purchase['validUntil'] != null)
                                Text(
                                  'Valid until: ${DateTime.parse(purchase['validUntil']).toLocal().toString().split(' ')[0]}',
                                  style: GoogleFonts.outfit(fontSize: 10, color: Colors.orange),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              if (purchase['fileUrl'] != null && purchase['fileUrl'].toString().isNotEmpty)
                                TextButton.icon(
                                   onPressed: () {
                                    final pdfUrl = purchase['fileUrl'].toString();
                                    final driveId = PdfUtils.extractDriveId(pdfUrl);
                                    PdfDownloadDialog.show(
                                      context,
                                      PdfFileModel(
                                        id: purchase['id'].toString(),
                                        name: '${purchase['name']} - Product File',
                                        driveFileId: driveId,
                                        url: driveId == null ? pdfUrl : null,
                                        subject: 'Purchased Content',
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.green),
                                  label: Text('PDF', style: GoogleFonts.outfit(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                ),
                              TextButton.icon(
                                onPressed: () {
                                  if (isSubscription) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => SubscriptionReceiptScreen(
                                          receiptNumber: purchase['receiptNumber']?.toString() ?? purchase['id'].toString(),
                                          planName: purchase['name'].toString(),
                                          amount: purchase['amount'].toString(),
                                          transactionId: purchase['transactionId']?.toString() ?? '',
                                          purchaseDate: purchase['date'].toString(),
                                          validUntil: purchase['validUntil']?.toString() ?? '',
                                        ),
                                      ),
                                    );
                                  } else {
                                    _viewReceipt(context, purchase);
                                  }
                                },
                                icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Colors.blue),
                                label: Text('RECEIPT', style: GoogleFonts.outfit(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),

                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _downloadReceipt(BuildContext context, Map<String, dynamic> purchase) async {
    final pdf = pw.Document();
    
    final date = DateTime.parse(purchase['date']).toLocal();
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    
    final ByteData logoData = await rootBundle.load('assets/logo.png');
    final Uint8List imageBytes = logoData.buffer.asUint8List();
    final pw.ImageProvider logo = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with logo and title
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Image(logo, width: 90, height: 90),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('TAX RECEIPT', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.amber800)),
                      pw.SizedBox(height: 6),
                      pw.Text('CBSE T0PPERS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Toppers 24/7 Learning App', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      pw.Text('Agra, Uttar Pradesh, India', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Divider(color: PdfColors.grey400, thickness: 1.5),
              pw.SizedBox(height: 24),
              
              // Customer & Order Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILLED TO:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.SizedBox(height: 6),
                      pw.Text('Valued Student', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('App User / Subscriber', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Order ID: ${purchase['id']}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text('Date: $formattedDate', style: const pw.TextStyle(fontSize: 11)),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green100,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                        ),
                        child: pw.Text('STATUS: PAID', style: pw.TextStyle(fontSize: 10, color: PdfColors.green800, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 40),
              
              // Items Table
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1.5),
                },
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('Item Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                      pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                      pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('Amount (INR)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text(purchase['name']?.toString() ?? 'Learning Material', style: const pw.TextStyle(fontSize: 11))),
                      pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('1', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 11))),
                      pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('₹${purchase['amount']}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11))),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              
              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                   pw.SizedBox(
                    width: 200,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 11)),
                            pw.Text('₹${purchase['amount']}', style: const pw.TextStyle(fontSize: 11)),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Tax (0%):', style: const pw.TextStyle(fontSize: 11)),
                            pw.Text('₹0', style: const pw.TextStyle(fontSize: 11)),
                          ],
                        ),
                        pw.SizedBox(height: 10),
                        pw.Divider(color: PdfColors.grey400),
                        pw.SizedBox(height: 10),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total Paid:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                            pw.Text('₹${purchase['amount']}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.amber800)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              pw.Spacer(),
              
              // Footer / Customer Service details
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('CUSTOMER SERVICE & SUPPORT', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text('Email: cbsetoppers@zohomail.in', style: pw.TextStyle(fontSize: 11, color: PdfColors.blue800)),
                        pw.SizedBox(width: 30),
                        pw.Text('WhatsApp: +91 9568902453', style: pw.TextStyle(fontSize: 11, color: PdfColors.green800)),
                      ],
                    ),
                    pw.SizedBox(height: 16),
                    pw.Text('Thank you for choosing CBSE TOPPERS! We are committed to your success.', 
                      style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
                      textAlign: pw.TextAlign.center),
                    pw.SizedBox(height: 4),
                    pw.Text('This is a computer-generated receipt and requires no physical signature.', 
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                      textAlign: pw.TextAlign.center),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final title = 'Receipt_${purchase['id']}';
    
    final path = await PlatformHelper.saveBytesToDevice(bytes: bytes, title: title);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb ? 'Receipt Downloaded!' : 'Receipt Saved to Downloads'),
          backgroundColor: Colors.green,
          action: !kIsWeb && path != null ? SnackBarAction(label: 'OPEN', textColor: Colors.white, onPressed: () => PlatformHelper.openFile(path)) : null,
        ),
      );
    }
  }

  void _viewReceipt(BuildContext context, Map<String, dynamic> purchase) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardBlack : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppTheme.primaryGold.withOpacity(0.5))),
        title: Text('RECEIPT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AppTheme.primaryGold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item: ${purchase['name']}', style: GoogleFonts.outfit(color: AppTheme.textHeadingColor)),
            const SizedBox(height: 8),
            Text('Order ID: ${purchase['id']}', style: GoogleFonts.outfit(color: AppTheme.textBodyColor.withOpacity(0.7))),
            const SizedBox(height: 8),
            Text('Amount: ${purchase['amount']}', style: GoogleFonts.outfit(color: AppTheme.textHeadingColor)),
            const SizedBox(height: 8),
            Text('Date: ${DateTime.parse(purchase['date']).toLocal().toString().split('.')[0]}', style: GoogleFonts.outfit(color: AppTheme.textBodyColor.withOpacity(0.7))),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text('PAID SUCCESSFULLY', style: GoogleFonts.outfit(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadReceipt(context, purchase);
            },
            child: Text('DOWNLOAD PDF', style: GoogleFonts.outfit(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE', style: GoogleFonts.outfit(color: isDark ? Colors.white54 : Colors.black54)),
          ),
        ],
      ),
    );
  }

}
