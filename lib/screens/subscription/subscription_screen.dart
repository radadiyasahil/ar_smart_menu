import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/subscription_service.dart';
import '../../providers/business_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  List<SubscriptionPlanModel> _plans = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
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

  Future<void> _handleActivateTrial() async {
    final businessProvider = context.read<BusinessProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await businessProvider.activateTrial();
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('🎉 7-Day Free Trial activated! All features are unlocked.'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showInvoiceConfirmDialog(SubscriptionPlanModel plan) {
    final businessProvider = context.read<BusinessProvider>();
    final business = businessProvider.business;
    final halfGst = plan.gstRupees / 2.0;

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
                          _buildInvoiceRow('CGST (9%)', '₹${halfGst.toStringAsFixed(2)}', isSubtext: true),
                          const SizedBox(height: 4),
                          _buildInvoiceRow('SGST (9%)', '₹${halfGst.toStringAsFixed(2)}', isSubtext: true),
                          const SizedBox(height: 6),
                          _buildInvoiceRow('Total 18% GST', '₹${plan.gstRupees.toStringAsFixed(2)}'),
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
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('🎉 ${plan.name} activated successfully! All services unlocked.'),
                                            backgroundColor: const Color(0xFF10B981),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } catch (err) {
                                      setDialogState(() => isActivating = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Activation failed: $err'),
                                            backgroundColor: const Color(0xFFEF4444),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
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
        title: const Text(
          'Subscription Plans',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () {
              _loadPlans();
              businessProvider.loadSubscription();
            },
            tooltip: 'Refresh plans',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5353)))
          : _error != null
              ? Center(
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
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Subscription Status Header Box
                      _buildCurrentStatusBanner(
                        hasActiveSub: hasActiveSub,
                        isTrialActive: isTrialActive,
                        daysRemaining: daysRemaining,
                        currentSub: currentSub,
                      ),
                      const SizedBox(height: 24),

                      // Section Title
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
                      const SizedBox(height: 18),

                      // Plans List
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
                ),
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
                        '+ 18% GST',
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
