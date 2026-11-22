import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/subscription_invoice_pdf_service.dart';
import '../../core/services/subscription_service.dart';
import '../../providers/business_provider.dart';
import '../../core/utils/top_toast.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  List<SubscriptionPlanModel> _plans = [];
  bool _isLoading = true;
  String? _error;

  int _selectedTab = 0; // 0 = Plans, 1 = History & Invoices
  List<SubscriptionHistoryItemModel> _history = [];
  bool _isLoadingHistory = false;
  String? _historyError;
  final Set<String> _downloadingInvoiceIds = {};

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
    _loadPlans();
    _loadHistory();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final plans = await _subscriptionService.getPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load plans: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });
    try {
      final history = await _subscriptionService.getHistory();
      if (mounted) {
        setState(() {
          _history = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyError = 'Failed to load subscription history: $e';
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _downloadInvoice(SubscriptionHistoryItemModel item) async {
    setState(() => _downloadingInvoiceIds.add(item.id));
    try {
      final invoice = await _subscriptionService.getInvoice(item.id);
      await SubscriptionInvoicePdfService.instance.downloadInvoicePdf(invoice);
      if (mounted) {
        TopToast.success(context, '📄 GST Tax Invoice #${item.invoiceNumber} downloaded successfully!');
      }
    } catch (e) {
      if (mounted) {
        TopToast.error(context, 'Could not generate invoice: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingInvoiceIds.remove(item.id));
      }
    }
  }

  Future<void> _shareInvoice(SubscriptionHistoryItemModel item) async {
    setState(() => _downloadingInvoiceIds.add(item.id));
    try {
      final invoice = await _subscriptionService.getInvoice(item.id);
      await SubscriptionInvoicePdfService.instance.shareInvoicePdf(invoice);
    } catch (e) {
      if (mounted) {
        TopToast.error(context, 'Could not share invoice: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingInvoiceIds.remove(item.id));
      }
    }
  }

  Future<void> _handleActivateTrial() async {
    final businessProvider = context.read<BusinessProvider>();
    try {
      await businessProvider.activateTrial();
      if (mounted) {
        TopToast.success(context, '🎉 7-Day Free Trial activated! All features are unlocked.');
      }
    } catch (e) {
      if (mounted) {
        TopToast.error(context, 'Error: $e');
      }
    }
  }

  void _showInvoiceConfirmDialog(SubscriptionPlanModel plan) {
    final businessProvider = context.read<BusinessProvider>();
    final business = businessProvider.business;
    final halfGst = plan.gstRupees / 2.0;
    final gstPct = plan.gstRatePercent;
    final halfPct = (gstPct / 2.0).toStringAsFixed(gstPct % 2 == 0 ? 0 : 1);
    final totalPct = gstPct.toStringAsFixed(gstPct.truncateToDouble() == gstPct ? 0 : 1);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        bool isActivating = false;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF181920),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: Color(0xFF2B2C38), width: 1.5)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${plan.durationDays} Days Duration • Instant Activation',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                        if (plan.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5353).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFF5353).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              plan.badge!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF5353),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2028),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2B2C38)),
                      ),
                      child: Column(
                        children: [
                          if (business != null) ...[
                            _buildInvoiceRow('Restaurant', business.businessName),
                            const Divider(color: Colors.white10, height: 16),
                          ],
                          _buildInvoiceRow('Plan Duration', '${plan.durationDays} Days'),
                          const Divider(color: Colors.white10, height: 16),
                          _buildInvoiceRow('Base Price', '₹${plan.basePriceRupees.toStringAsFixed(2)}'),
                          const SizedBox(height: 6),
                          _buildInvoiceRow('CGST ($halfPct%)', '₹${halfGst.toStringAsFixed(2)}', isSubtext: true),
                          const SizedBox(height: 4),
                          _buildInvoiceRow('SGST ($halfPct%)', '₹${halfGst.toStringAsFixed(2)}', isSubtext: true),
                          const SizedBox(height: 6),
                          _buildInvoiceRow('Total $totalPct% GST', '₹${plan.gstRupees.toStringAsFixed(2)}'),
                          const Divider(color: Colors.white24, height: 20),
                          _buildInvoiceRow(
                            'Total Amount Payable',
                            '₹${plan.totalPriceRupees.toStringAsFixed(2)}',
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'GST Tax Invoice generated instantly. All features unlock immediately upon activation.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isActivating ? null : () => Navigator.of(dialogCtx).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF34384B)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Back', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isActivating
                                ? null
                                : () async {
                                    setDialogState(() => isActivating = true);
                                    try {
                                      await businessProvider.activatePlan(
                                        planId: plan.id,
                                        paymentMethod: 'UPI',
                                        transactionRef: 'SIM_TXN_${DateTime.now().millisecondsSinceEpoch}',
                                      );
                                      if (dialogCtx.mounted) {
                                        Navigator.of(dialogCtx).pop();
                                      }
                                      if (mounted) {
                                        TopToast.success(context, '🎉 ${plan.name} activated successfully! All services unlocked.');
                                      }
                                    } catch (err) {
                                      setDialogState(() => isActivating = false);
                                      if (mounted) {
                                        TopToast.error(context, 'Activation failed: $err');
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5353),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                            ),
                            child: isActivating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    'Confirm & Pay ₹${plan.totalPriceRupees.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInvoiceRow(String label, String value, {bool isTotal = false, bool isSubtext = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14 : isSubtext ? 11 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? Colors.white : isSubtext ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : isSubtext ? 11 : 13,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
            color: isTotal ? const Color(0xFF10B981) : isSubtext ? const Color(0xFF9CA3AF) : Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessProvider = context.watch<BusinessProvider>();
    final currentSub = businessProvider.subscription;
    final hasActiveSub = businessProvider.hasActiveSubscription;
    final isTrialActive = businessProvider.isTrial;
    final daysRemaining = businessProvider.daysRemaining;
    final hasUsedTrial = businessProvider.hasUsedTrial;

    return Scaffold(
      backgroundColor: const Color(0xFF121319),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181920),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _selectedTab == 0 ? 'Subscription Plans' : 'Subscription & GST Bills',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () {
              _loadPlans();
              _loadHistory();
              businessProvider.loadSubscription();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Segmented Tab Selector (Plans vs History & GST Bills)
          _buildTabSelector(),

          // Tab Body
          Expanded(
            child: _selectedTab == 0
                ? _buildPlansTab(
                    hasActiveSub: hasActiveSub,
                    isTrialActive: isTrialActive,
                    daysRemaining: daysRemaining,
                    currentSub: currentSub,
                    hasUsedTrial: hasUsedTrial,
                  )
                : _buildHistoryTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF181920),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2B2C38)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? const Color(0xFFFF5353) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Plans & Upgrades',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? const Color(0xFFFF5353) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'History & GST Bills${_history.isNotEmpty ? ' (${_history.length})' : ''}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansTab({
    required bool hasActiveSub,
    required bool isTrialActive,
    required int daysRemaining,
    required SubscriptionInfoModel? currentSub,
    required bool hasUsedTrial,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5353)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadPlans,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5353)),
              child: const Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCurrentStatusBanner(
            hasActiveSub: hasActiveSub,
            isTrialActive: isTrialActive,
            daysRemaining: daysRemaining,
            currentSub: currentSub,
          ),
          const SizedBox(height: 20),

          const Text(
            'Select a Plan for Your Business',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Transparent HORECA rates with 18% GST • All plans unlock full 3D AR & billing POS',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 16),

          ..._plans.map((plan) => _buildPlanCard(
                plan: plan,
                currentSub: currentSub,
                hasUsedTrial: hasUsedTrial,
              )),

          const SizedBox(height: 24),
          _buildFaqSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5353)),
      );
    }

    if (_historyError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 40),
              const SizedBox(height: 12),
              Text(
                _historyError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFEF4444)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5353)),
                onPressed: _loadHistory,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFFF5353),
      onRefresh: _loadHistory,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Government Audit & Return Compliant Explanatory Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Government Tax Return & Audit Ready',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Download official GST Tax Invoices (SAC 998313, 18% GST breakup) for claiming Input Tax Credit (ITC) on GSTR-2B/3B and IT department audits.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_history.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_outlined, color: Colors.white38, size: 32),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Past Subscriptions Yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your subscription activations, renewals, and official GST tax invoices will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.star_rounded, size: 18),
                      label: const Text('View Available Plans'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5353)),
                      onPressed: () => setState(() => _selectedTab = 0),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._history.map((item) => _buildHistoryCard(item)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(SubscriptionHistoryItemModel item) {
    final isDownloading = _downloadingInvoiceIds.contains(item.id);
    final fmt = DateFormat('dd MMM yyyy');
    final invoiceDateStr = fmt.format(item.invoiceDate);
    final periodStr = '${fmt.format(item.startsAt)} → ${fmt.format(item.endsAt)}';

    final isActive = item.status.toLowerCase() == 'active' && item.endsAt.isAfter(DateTime.now());
    final isTrial = item.isTrial;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181920),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFF2B2C38),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Plan Name & Status Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.planName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item.durationDays}D',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : isTrial
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : isTrial
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                            : Colors.white12,
                  ),
                ),
                child: Text(
                  isActive ? 'Active Plan' : isTrial ? '7D Trial' : 'Completed',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isActive
                        ? const Color(0xFF10B981)
                        : isTrial
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Invoice Number & Date
          Row(
            children: [
              const Icon(Icons.receipt_outlined, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text(
                'Invoice: #${item.invoiceNumber}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: item.invoiceNumber));
                  TopToast.success(context, 'Copied invoice number #${item.invoiceNumber}');
                },
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.copy_rounded, size: 13, color: Color(0xFF6B7280)),
                ),
              ),
              const Spacer(),
              Text(
                invoiceDateStr,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Service Period
          Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text(
                'Validity: $periodStr',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFF2B2C38), height: 1),
          const SizedBox(height: 10),

          // Price Breakdown Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Base Amount', style: TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF))),
                  Text(
                    '₹${item.baseAmountRupees.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item.gstRatePercent.toStringAsFixed(item.gstRatePercent.truncateToDouble() == item.gstRatePercent ? 0 : 1)}% GST (SAC 998313)', style: const TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF))),
                  Text(
                    '₹${item.gstRupees.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Total Paid', style: TextStyle(fontSize: 10.5, color: Color(0xFF10B981))),
                  Text(
                    '₹${item.totalAmountRupees.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                  ),
                ],
              ),
            ],
          ),

          if (item.paymentRef != null && item.paymentRef!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Mode: ${item.paymentMethod ?? "Online"} • Ref: ${item.paymentRef}',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280)),
            ),
          ],

          const SizedBox(height: 14),

          // Action Buttons: Download GST Tax Invoice & Share
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: isDownloading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded, size: 16),
                  label: Text(
                    isDownloading ? 'Generating...' : 'Download GST Invoice',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isDownloading ? null : () => _downloadInvoice(item),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.share_outlined, size: 18, color: Colors.white70),
                tooltip: 'Share Invoice PDF',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF262734),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isDownloading ? null : () => _shareInvoice(item),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.white70),
                tooltip: 'View Invoice Details',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF262734),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showInvoiceDetailsModal(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInvoiceDetailsModal(SubscriptionHistoryItemModel item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return FutureBuilder<SubscriptionInvoiceModel>(
          future: _subscriptionService.getInvoice(item.id),
          builder: (modalCtx, snapshot) {
            final inv = snapshot.data;

            return Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFF181920),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: Color(0xFF2B2C38), width: 1.5)),
              ),
              child: SafeArea(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFFFF5353))),
                      )
                    : inv == null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                snapshot.error?.toString() ?? 'Could not load invoice details',
                                style: const TextStyle(color: Color(0xFFEF4444)),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Container(
                                    width: 44,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TAX INVOICE #${inv.invoiceNumber}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Date: ${DateFormat('dd MMM yyyy').format(inv.invoiceDate)} • SAC: ${inv.sacCode}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'PAID ✔',
                                        style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Divider(color: Color(0xFF2B2C38)),
                                const SizedBox(height: 10),

                                // Supplier Details
                                const Text('SERVICE PROVIDER / SELLER', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
                                const SizedBox(height: 2),
                                Text(inv.supplierName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text('GSTIN: ${inv.supplierGstNumber} • State: ${inv.supplierState} (${inv.supplierStateCode})', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                                const SizedBox(height: 12),

                                // Buyer Details
                                const Text('BILLED TO / BUYER', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
                                const SizedBox(height: 2),
                                Text(inv.customerBusinessName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text('GSTIN: ${inv.customerGstNumber ?? "URP (Unregistered Person)"}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                                Text(inv.customerAddress, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                const SizedBox(height: 14),
                                const Divider(color: Color(0xFF2B2C38)),
                                const SizedBox(height: 10),

                                // Amounts Breakdown
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Taxable Value (Base):', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                                    Text('₹${inv.baseAmountRupees.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (inv.isInterState)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Integrated GST (IGST @ ${inv.igstRate.toStringAsFixed(inv.igstRate.truncateToDouble() == inv.igstRate ? 0 : 1)}%):', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                                      Text('₹${inv.igstRupees.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                    ],
                                  )
                                else ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Central GST (CGST @ ${inv.cgstRate.toStringAsFixed(inv.cgstRate.truncateToDouble() == inv.cgstRate ? 0 : 1)}%):', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                                      Text('₹${inv.cgstRupees.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('State GST (SGST @ ${inv.sgstRate.toStringAsFixed(inv.sgstRate.truncateToDouble() == inv.sgstRate ? 0 : 1)}%):', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                                      Text('₹${inv.sgstRupees.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 10),
                                const Divider(color: Color(0xFF2B2C38)),
                                const SizedBox(height: 8),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Invoice Amount:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('₹${inv.totalAmountRupees.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 17)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(inv.amountInWords, style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF9CA3AF))),
                                const SizedBox(height: 20),

                                // Modal Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.download_rounded, size: 16),
                                        label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _downloadInvoice(item);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.share_outlined, size: 16),
                                        label: const Text('Share PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: const BorderSide(color: Color(0xFF334155)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _shareInvoice(item);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCurrentStatusBanner({
    required bool hasActiveSub,
    required bool isTrialActive,
    required int daysRemaining,
    required SubscriptionInfoModel? currentSub,
  }) {
    if (hasActiveSub) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isTrialActive ? '7-Day Free Trial' : (currentSub?.planName ?? 'Active Plan'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🟢 $daysRemaining days remaining • All features unlocked',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF34D399), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isExpired = currentSub != null && currentSub.status == 'Expired';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: (isExpired ? const Color(0xFFEF4444) : const Color(0xFFFF5353)).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isExpired ? const Color(0xFFEF4444) : const Color(0xFFFF5353)).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isExpired ? const Color(0xFFEF4444) : const Color(0xFFFF5353)).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isExpired ? Icons.lock_clock_rounded : Icons.flash_on_rounded,
              color: isExpired ? const Color(0xFFEF4444) : const Color(0xFFFF5353),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired ? 'Subscription Expired' : 'No Active Plan Selected',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isExpired
                      ? 'Service ended. Please renew to restore ordering and dish editing.'
                      : 'Start with 7-Day Free Trial or select an affordable plan below.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required SubscriptionPlanModel plan,
    required SubscriptionInfoModel? currentSub,
    required bool hasUsedTrial,
  }) {
    final isCurrent = currentSub != null &&
        currentSub.isActive &&
        currentSub.plan?.id == plan.id;
    final isPopular = plan.slug == 'plan-6-months';
    final isBestValue = plan.slug == 'plan-1-year';
    final isTrial = plan.isTrial;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF181920),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF10B981)
              : isBestValue
                  ? const Color(0xFFF59E0B)
                  : isPopular
                      ? const Color(0xFFFF5353)
                      : const Color(0xFF2B2C38),
          width: isCurrent || isPopular || isBestValue ? 2 : 1,
        ),
        boxShadow: [
          if (isPopular || isBestValue)
            BoxShadow(
              color: (isBestValue ? const Color(0xFFF59E0B) : const Color(0xFFFF5353)).withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badge
          if (plan.badge != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isBestValue
                    ? const Color(0xFFF59E0B)
                    : isPopular
                        ? const Color(0xFFFF5353)
                        : const Color(0xFF262733),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Center(
                child: Text(
                  plan.badge!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan Name and Duration
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF242735),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${plan.durationDays} Days',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  plan.description,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), height: 1.35),
                ),
                const SizedBox(height: 16),

                // Pricing Section
                if (isTrial) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text(
                        '₹0',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'for 7 days',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'No Credit Card Required • Instant Activation',
                    style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                  ),
                ] else ...[
                  // Price with strikethrough if discounted
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹${plan.basePriceRupees.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      if (plan.originalPriceRupees != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          '₹${plan.originalPriceRupees!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        '+ ${plan.gstRatePercent.toStringAsFixed(plan.gstRatePercent.truncateToDouble() == plan.gstRatePercent ? 0 : 1)}% GST',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Total Payable: ₹${plan.totalPriceRupees.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(~₹${plan.effectiveMonthlyRupees.toStringAsFixed(0)}/mo)',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 18),
                const Divider(color: Colors.white10),
                const SizedBox(height: 14),

                // Facilities List
                const Text(
                  'INCLUDED FACILITIES:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                ...plan.facilities.map((facility) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 10),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              facility,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFFD1D5DB),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 20),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCurrent
                        ? null
                        : isTrial
                            ? (hasUsedTrial ? null : _handleActivateTrial)
                            : () => _showInvoiceConfirmDialog(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBestValue
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFFF5353),
                      disabledBackgroundColor: const Color(0xFF2B2C38),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: isCurrent ? 0 : 3,
                    ),
                    child: Text(
                      isCurrent
                          ? 'Current Active Plan'
                          : isTrial
                              ? (hasUsedTrial ? 'Free Trial Already Used' : 'Start 7-Day Free Trial')
                              : 'Activate Plan (${plan.durationDays >= 365 ? '1 Year' : '${plan.durationDays ~/ 30} Months'})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isCurrent || (isTrial && hasUsedTrial)
                            ? const Color(0xFF9CA3AF)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF181920),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2B2C38)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded, color: Color(0xFFFF5353), size: 18),
              SizedBox(width: 8),
              Text(
                'Frequently Asked Questions',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '• What happens after the 7-day free trial?',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          SizedBox(height: 2),
          Text(
            'After 7 days, your account switches to read-only until you choose an affordable 3, 6, or 12-month plan. You never lose any menu dishes or QR codes.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
          ),
          SizedBox(height: 10),
          Text(
            '• How is 18% GST charged?',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          SizedBox(height: 2),
          Text(
            'GST is split into 9% CGST + 9% SGST for intra-state or 18% IGST. A formal tax invoice with your GSTIN is provided for full input tax credit.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}
