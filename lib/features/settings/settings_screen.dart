import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../database/app_database.dart';
import '../../database/database_seeder.dart';
import '../../providers/app_providers.dart';
import '../../services/csv_service.dart';
import '../onboarding/onboarding_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Shop Profile Card
            _buildShopProfileCard(),
            const SizedBox(height: 16),

            // 2. Supplier CSV Catalog Import
            _buildCsvImportCard(),
            const SizedBox(height: 16),

            // 3. Tobacco & Cigarette Compliance Guidelines
            _buildComplianceCard(),
            const SizedBox(height: 16),

            // 4. Store Data Management & Reset
            _buildDataResetCard(context),
            const SizedBox(height: 16),

            // 5. Privacy Policy & Data Security
            _buildPrivacyPolicyCard(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShopProfileCard() {
    final profile = ref.watch(shopProfileProvider);
    final hasConfig = profile.isConfigured && profile.shopName.isNotEmpty;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.store, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasConfig ? profile.shopName : 'My Retail Store',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        hasConfig ? (profile.shopOwner.isNotEmpty ? profile.shopOwner : 'Retail Store & Business Profile') : 'Setup your store profile',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    InkWell(
                      onTap: () => _editShopProfileDialog(profile),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded, size: 14, color: Color(0xFF0D5C46)),
                            SizedBox(width: 4),
                            Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D5C46))),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OnboardingScreen(
                              onCompleted: () => Navigator.pop(context),
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _infoRow('Shop Name', profile.shopName.isEmpty ? 'Not set (tap Edit)' : profile.shopName),
            _infoRow('Shop Owner', profile.shopOwner.isEmpty ? 'Not set' : profile.shopOwner),
            _infoRow('Address', profile.address.isEmpty ? 'Not set' : profile.address),
            _infoRow('GSTIN', profile.gstin.isEmpty ? 'Not Provided' : profile.gstin),
            _infoRow('Contact Phone', profile.phone.isEmpty ? 'Not set' : profile.phone),
            _infoRow('System Mode', 'Offline-First SQLite Database Engine'),
          ],
        ),
      ),
    );
  }

  void _editShopProfileDialog(ShopProfile current) {
    final nameCtrl = TextEditingController(text: current.shopName);
    final ownerCtrl = TextEditingController(text: current.shopOwner);
    final addrCtrl = TextEditingController(text: current.address);
    final gstinCtrl = TextEditingController(text: current.gstin);
    final phoneCtrl = TextEditingController(text: current.phone);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Shop Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Shop Name',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ownerCtrl,
                    decoration: InputDecoration(
                      labelText: 'Owner / Proprietor Name',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addrCtrl,
                    decoration: InputDecoration(
                      labelText: 'Store Address',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(
                      labelText: 'Contact Phone Number',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: gstinCtrl,
                    decoration: InputDecoration(
                      labelText: 'GSTIN',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D5C46),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final updated = current.copyWith(
                  shopName: nameCtrl.text.trim(),
                  shopOwner: ownerCtrl.text.trim(),
                  address: addrCtrl.text.trim(),
                  gstin: gstinCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  isConfigured: true,
                );
                await ref.read(shopProfileProvider.notifier).updateProfile(updated);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shop profile updated successfully!')),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }


  Widget _buildCsvImportCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.upload_file, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Supplier CSV / Excel Catalogue Import', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Import new wholesale supplier catalogues into your shop inventory without modifying code.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload, size: 16),
                  label: const Text('Import Supplier CSV'),
                  onPressed: _openCsvImportDialog,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.description, size: 16),
                  label: const Text('View Sample CSV Template'),
                  onPressed: _viewSampleTemplateDialog,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openCsvImportDialog() {
    final csvCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Paste Supplier CSV Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Paste CSV text containing headers: name, brand, category, purchase_price, selling_price, opening_stock, etc.', style: TextStyle(fontSize: 11)),
                const SizedBox(height: 8),
                TextField(
                  controller: csvCtrl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'name,brand,category,purchase_price,selling_price,opening_stock\nBritannia Marie Gold,Britannia,Bakery,28.00,35.00,20',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final text = csvCtrl.text.trim();
                if (text.isEmpty) return;

                final result = CsvService.parseSupplierCsv(text);
                if (result.errors.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import errors: ${result.errors.join(", ")}')));
                }

                for (final item in result.importedItems) {
                  await ref.read(inventoryRepoProvider).upsertItem(item);
                }

                ref.invalidate(inventoryListProvider);
                ref.invalidate(dashboardMetricsProvider);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Successfully imported ${result.successfullyImported} supplier items into shop inventory!'),
                  ));
                }
              },
              child: const Text('Import CSV'),
            ),
          ],
        );
      },
    );
  }

  void _viewSampleTemplateDialog() async {
    try {
      final template = await rootBundle.loadString('assets/data/supplier_import_template.csv');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Supplier CSV Import Format', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.grey.shade100,
                  child: SelectableText(template, style: const TextStyle(fontFamily: 'Consolas', fontSize: 11)),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            );
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildComplianceCard() {
    return Card(
      color: Colors.brown.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.brown.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Colors.teal.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('FSSAI Food Safety & Retail Standards', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                ),
              ],
            ),
            const Divider(height: 16),
            _complianceRule('100% Pure Food & Snack Catalogue', 'Shop Track maintains an authentic database of packaged namkeen, wafers, bakery, and snacks.'),
            _complianceRule('Batch & Expiry Vigilance', 'Ensure stock rotation following First-In First-Out (FIFO) standards for fresh consumer delivery.'),
            _complianceRule('MRP & Weight Integrity', 'All master products reflect manufacturer declared net quantities and standard retail price tiers (₹5, ₹10, ₹20, ₹30).'),
          ],
        ),
      ),
    );
  }

  Widget _complianceRule(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• $title:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
          Text(desc, style: TextStyle(fontSize: 10, color: Colors.teal.shade800)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataResetCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cleaning_services_rounded, color: Color(0xFFDC2626), size: 20),
                SizedBox(width: 8),
                Text('Store Data Management', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Reset all active inventory stock, sales records, purchase orders, and operating expenses to start completely fresh at 0. Verified Master Catalogue items will be kept intact.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: const Text('Reset All Store Data to Clean Slate'),
              onPressed: () => _confirmResetDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Store Data?'),
        content: const Text(
          'This will permanently clear all stocked inventory, past sales history, inward purchases, and expenses. Your store will start with a fresh 0-balance.\n\nThe Master Product Catalogue will remain available to stock items anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final db = await AppDatabase.instance.database;
              await DatabaseSeeder.clearAllStoreData(db);
              ref.invalidate(inventoryListProvider);
              ref.invalidate(inventoryValuationProvider);
              ref.invalidate(dashboardMetricsProvider);
              ref.invalidate(dailySalesChartProvider);
              ref.invalidate(topSellingProductsProvider);
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('All demo store data cleared. Your shop is now at a clean slate!')),
                );
              }
            },
            child: const Text('Yes, Reset Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicyCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D5C46).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF0D5C46), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy Policy & Data Security',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '100% Offline-First • Zero Cloud Tracking • Local SQLite',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Shop Track is designed with strict offline-first principles. Your commercial ledger, inventory records, sales transactions, and supplier contacts remain stored exclusively on your device.',
              style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D5C46),
                  side: const BorderSide(color: Color(0xFF0D5C46)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Read Full Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showPrivacyPolicyDialog(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Color(0xFF0D5C46), size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Privacy Policy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Last Updated: October 2026\nApplication: Shop Track (Business Tracker)',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
                SizedBox(height: 12),
                Text(
                  '1. Overview & Commitment',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D5C46)),
                ),
                SizedBox(height: 4),
                Text(
                  'Shop Track respects the confidentiality and privacy of FMCG merchants and retail business owners. We operate an offline-first architecture to guarantee maximum privacy and autonomy.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                SizedBox(height: 12),
                Text(
                  '2. Data Stored Exclusively on Your Device',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D5C46)),
                ),
                SizedBox(height: 4),
                Text(
                  'All store records—including item purchase costs, retail selling prices, inventory balances, order histories, supplier records, and customer receipts—are stored locally in your device\'s SQLite database. We do not transmit or host your operational business records on remote cloud servers.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                SizedBox(height: 12),
                Text(
                  '3. Device Permissions & Usage',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D5C46)),
                ),
                SizedBox(height: 4),
                Text(
                  '• Storage / Media: Used strictly when you explicitly export PDF valuation reports or CSV balance sheets to your device.\n• Camera (Optional): Used only for local barcode scanning when stocking products.\n• Internet (Optional): Used solely to load verified public product images or catalogue metadata.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                SizedBox(height: 12),
                Text(
                  '4. Zero Third-Party Monetization',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D5C46)),
                ),
                SizedBox(height: 4),
                Text(
                  'We do not sell, rent, license, or share your business data, financial metrics, customer phone numbers, or supplier agreements with data brokers, advertisers, or analytics aggregators.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                SizedBox(height: 12),
                Text(
                  '5. Data Retention & Full Deletion Control',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D5C46)),
                ),
                SizedBox(height: 4),
                Text(
                  'You retain complete ownership of your data at all times. You can wipe all inventory records, sales transactions, and expense ledgers instantly using the "Reset All Store Data" tool in Settings, or by uninstalling the application.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                SizedBox(height: 12),
                Text(
                  '6. Contact & Inquiries',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D5C46)),
                ),
                SizedBox(height: 4),
                Text(
                  'If you have questions regarding this Privacy Policy, please contact our support team at:\nsupport@shoptrackapp.com',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D5C46),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
