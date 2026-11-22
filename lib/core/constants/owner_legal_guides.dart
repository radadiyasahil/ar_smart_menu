class PolicyGuideItem {
  final String heading;
  final String body;

  const PolicyGuideItem({
    required this.heading,
    required this.body,
  });
}

class OwnerLegalGuides {
  static const List<PolicyGuideItem> ownerFaq = [
    PolicyGuideItem(
      heading: 'How do customers view our 3D AR menu?',
      body:
          'Customers simply point their smartphone camera to scan the Table QR stand. No app download or account creation is needed. Dishes open instantly in their mobile browser in realistic 3D with Augmented Reality directly on their table before ordering.',
    ),
    PolicyGuideItem(
      heading: 'How do Live Table Orders, Rounds & KOT work?',
      body:
          'When diners place an order, it arrives in real-time in your Orders & Kitchen dashboard. You can review items, send tickets to the kitchen, print KOT slips, or enable Auto-KOT for instant automatic kitchen dispatch. Subsequent rounds from the same table are seamlessly grouped.',
    ),
    PolicyGuideItem(
      heading: 'What is Dine-in Anti-Fraud (Table PIN & Geofence)?',
      body:
          '• Table PIN: Once a table has an active order, new guests at that table enter the 3-digit PIN to join the party session, preventing accidental double-ordering.\n• Geofence Protection: Restricts ordering exclusively to guests physically seated inside your restaurant radius (e.g. 30m - 200m), eliminating fake remote orders.',
    ),
    PolicyGuideItem(
      heading: 'How do customer bills and payments work?',
      body:
          'Guests can pay directly via dynamic UPI QR code (Google Pay, PhonePe, Paytm, etc.) or cash at the counter. AR Smart Menu charges 0% commission on your food and beverage sales — 100% of diner payments go directly to you.',
    ),
    PolicyGuideItem(
      heading: 'How to download GST invoices for government audit?',
      body:
          'Go to Settings > General Settings & Billing > Past Subscriptions to download official A4 GST Tax Invoices (including CGST, SGST, IGST, and SAC code 998313) for your tax return and audit filing.',
    ),
  ];

  static const List<PolicyGuideItem> termsOfService = [
    PolicyGuideItem(
      heading: 'Zero Commission Policy (100% Direct Payouts)',
      body:
          'AR Smart Menu operates as a pure software-as-a-service (SaaS) platform. We charge zero commissions or revenue cuts on your food, beverage, or table turnover. 100% of diner payments belong to your restaurant.',
    ),
    PolicyGuideItem(
      heading: 'Subscription & Feature Licensing',
      body:
          'Access to interactive 3D AR models, unlimited table ordering, kitchen management, POS billing, and real-time analytics is governed by your active subscription plan. You can renew or extend plans anytime without locked contracts or hidden fees.',
    ),
    PolicyGuideItem(
      heading: 'Menu & Intellectual Property Rights',
      body:
          'Your restaurant retains 100% intellectual property ownership of your food menu items, descriptions, recipes, photography, trademarks, and custom pricing.',
    ),
    PolicyGuideItem(
      heading: 'Platform Uptime & Service Reliability',
      body:
          'We provide high-performance cloud infrastructure with 99.9% uptime for diner QR menus and kitchen order synchronization. Real-time updates ensure seamless table turnover during peak hours.',
    ),
    PolicyGuideItem(
      heading: 'Food Safety & Operational Responsibility',
      body:
          'Restaurants remain responsible for maintaining valid FSSAI licenses, adhering to food hygiene standards, and ensuring accurate menu pricing and taxes in compliance with applicable local food regulations.',
    ),
  ];

  static const List<PolicyGuideItem> privacyPolicy = [
    PolicyGuideItem(
      heading: 'Zero Data Selling Commitment',
      body:
          'Your restaurant sales data, customer orders, revenue figures, and guest phone numbers are strictly private. We never sell, share, or monetize your restaurant data to third-party aggregators, advertisers, or competitors.',
    ),
    PolicyGuideItem(
      heading: 'Diner Order & Communication Security',
      body:
          'All communications between diner smartphones, table QR codes, and your restaurant kitchen are encrypted using industry-standard SSL/TLS protocols.',
    ),
    PolicyGuideItem(
      heading: 'Confidentiality of Financial & Tax Details',
      body:
          'Your FSSAI license number, GSTIN, bank account numbers, IFSC codes, and UPI IDs are securely encrypted and used exclusively for payment settlements and official tax invoicing.',
    ),
    PolicyGuideItem(
      heading: 'Full Data Control & Export',
      body:
          'You own your data. You can download and export comprehensive sales reports, billing history, and menu items anytime for auditing, or request complete account archiving if you choose to pause operations.',
    ),
  ];
}
