import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_leadership_quest/constants/app_constants.dart';
import 'package:my_leadership_quest/services/lead_market_service.dart';
import 'package:my_leadership_quest/services/organization_settings_service.dart';
import 'package:my_leadership_quest/services/supabase_service.dart';
import 'package:my_leadership_quest/utils/lead_market_branding.dart';

class SponsorDashboardScreen extends StatefulWidget {
  const SponsorDashboardScreen({super.key});

  @override
  State<SponsorDashboardScreen> createState() => _SponsorDashboardScreenState();
}

class _SponsorDashboardScreenState extends State<SponsorDashboardScreen> {
  final _client = SupabaseService.instance.client;
  final _marketService = LeadMarketService();
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _sponsorMemberships = [];
  String? _activeSponsorId;
  SponsorStorefront? _activeStorefront;

  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic>? get _activeSponsorRow {
    if (_activeSponsorId == null) return null;
    for (final m in _sponsorMemberships) {
      if ((m['sponsor_id'] ?? '').toString() == _activeSponsorId) return m;
    }
    return null;
  }

  void _syncActiveStorefront() {
    final sponsors = _activeSponsorRow?['sponsors'];
    if (sponsors is Map) {
      _activeStorefront = SponsorStorefront.fromJson(
        Map<String, dynamic>.from(sponsors),
      );
    } else {
      _activeStorefront = null;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Not signed in');
      }

      final memberships = await _client
          .from('sponsor_users')
          .select(
            'sponsor_id, role, sponsors(id, name, logo_url, banner_url, description, theme_primary_color, theme_secondary_color)',
          )
          .eq('user_id', userId);

      _sponsorMemberships = (memberships as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();

      _activeSponsorId ??= _sponsorMemberships.isNotEmpty
          ? (_sponsorMemberships.first['sponsor_id'] ?? '').toString()
          : null;

      _syncActiveStorefront();
      await _loadProducts();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadProducts() async {
    if (_activeSponsorId == null || _activeSponsorId!.isEmpty) {
      _products = [];
      return;
    }

    final res = await _client
        .from('market_products')
        .select(
          'id, name, image_url, status, stock_total, stock_available, price_coins, product_kind, value_weight',
        )
        .eq('sponsor_id', _activeSponsorId!)
        .order('created_at', ascending: false);

    _products = (res as List).map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<String?> _uploadBrandingImage(String label) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    if (f.bytes == null) return null;

    return OrganizationSettingsService.instance.uploadPublicAsset(
      f.bytes!,
      f.name,
      folder: 'lead-market/branding',
    );
  }

  Future<void> _editStorefrontBranding() async {
    final sponsorId = _activeSponsorId;
    final storefront = _activeStorefront;
    if (sponsorId == null || storefront == null) return;

    final descriptionController =
        TextEditingController(text: storefront.description ?? '');
    final primaryController =
        TextEditingController(text: storefront.themePrimaryColor ?? '');
    final secondaryController =
        TextEditingController(text: storefront.themeSecondaryColor ?? '');

    String? pendingLogoUrl = storefront.logoUrl;
    String? pendingBannerUrl = storefront.bannerUrl;
    bool saving = false;

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: const Text('Storefront branding'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Upload a logo and banner so students recognize your storefront in Lead Market.',
                  style: GoogleFonts.nunito(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final url = await _uploadBrandingImage('logo');
                          if (url == null) return;
                          setModal(() => pendingLogoUrl = url);
                        },
                  icon: const Icon(Icons.account_circle_outlined),
                  label: Text(
                    pendingLogoUrl?.isNotEmpty == true
                        ? 'Logo uploaded'
                        : 'Upload logo',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final url = await _uploadBrandingImage('banner');
                          if (url == null) return;
                          setModal(() => pendingBannerUrl = url);
                        },
                  icon: const Icon(Icons.panorama_outlined),
                  label: Text(
                    pendingBannerUrl?.isNotEmpty == true
                        ? 'Banner uploaded'
                        : 'Upload banner',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: primaryController,
                  decoration: const InputDecoration(
                    labelText: 'Primary color',
                    hintText: '#6B21A8',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: secondaryController,
                  decoration: const InputDecoration(
                    labelText: 'Secondary color',
                    hintText: '#9333EA',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Storefront description',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      setModal(() => saving = true);
                      final res = await _marketService.updateStorefrontBranding(
                        sponsorId: sponsorId,
                        logoUrl: pendingLogoUrl,
                        bannerUrl: pendingBannerUrl,
                        themePrimaryColor: primaryController.text.trim().isEmpty
                            ? null
                            : primaryController.text.trim(),
                        themeSecondaryColor:
                            secondaryController.text.trim().isEmpty
                                ? null
                                : secondaryController.text.trim(),
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                      );
                      if (!ctx.mounted) return;
                      if (res['ok'] == true) {
                        Navigator.pop(ctx, true);
                      } else {
                        setModal(() => saving = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Could not save branding: ${res['error'] ?? 'unknown'}',
                            ),
                          ),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storefront branding saved')),
      );
    }
  }

  Future<void> _createProduct() async {
    if (_activeSponsorId == null) return;

    final nameController = TextEditingController();
    final stockController = TextEditingController(text: '10');
    Uint8List? imageBytes;
    String? imageName;

    Future<void> pickImage(StateSetter setModal) async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      if (f.bytes == null) return;
      setModal(() {
        imageBytes = f.bytes;
        imageName = f.name;
      });
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: const Text('Add product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Product name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock donated'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      imageName ?? 'No image selected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => pickImage(setModal),
                    child: const Text('Choose image'),
                  )
                ],
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final stock = int.tryParse(stockController.text.trim()) ?? 0;
      if (stock <= 0) throw Exception('Stock must be > 0');

      String? imageUrl;
      if (imageBytes != null && imageName != null) {
        imageUrl = await OrganizationSettingsService.instance.uploadPublicAsset(
          imageBytes!,
          imageName!,
          folder: 'lead-market/products',
        );
      }

      await _client.from('market_products').insert({
        'sponsor_id': _activeSponsorId,
        'name': nameController.text.trim(),
        'image_url': imageUrl,
        'stock_total': stock,
        'stock_available': stock,
        'status': 'active',
      });

      try {
        await _client.rpc('market_update_prices_global');
      } catch (_) {}

      await _loadProducts();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Widget _buildBrandingPreview() {
    final storefront = _activeStorefront;
    if (storefront == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SponsorBrandedBanner(
              sponsor: storefront,
              height: 100,
              borderRadius: BorderRadius.zero,
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SponsorLogoAvatar(
                    logoUrl: storefront.logoUrl,
                    name: storefront.name,
                    primary: LeadMarketBranding.primaryColor(storefront),
                    secondary: LeadMarketBranding.secondaryColor(storefront),
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storefront.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          storefront.description?.isNotEmpty == true
                              ? storefront.description!
                              : 'Add a description for your storefront.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _editStorefrontBranding,
                    icon: const Icon(Icons.brush_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EAF7),
      appBar: AppBar(
        title: const Text('Sponsor Dashboard'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          if (_activeSponsorId != null)
            IconButton(
              onPressed: _createProduct,
              icon: const Icon(Icons.add),
              tooltip: 'Add product',
            )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _sponsorMemberships.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 64,
                              color: AppColors.primary.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No sponsor access',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ask an MLQ admin to onboard you as a sponsor user before managing products or storefront branding.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _activeSponsorId,
                                  decoration: const InputDecoration(
                                    labelText: 'Sponsor account',
                                    filled: true,
                                  ),
                                  items: _sponsorMemberships
                                      .map((m) {
                                        final s = (m['sponsors'] as Map?) ?? {};
                                        return DropdownMenuItem(
                                          value: (m['sponsor_id'] ?? '').toString(),
                                          child: Text((s['name'] ?? 'Sponsor').toString()),
                                        );
                                      })
                                      .toList(),
                                  onChanged: (val) async {
                                    _activeSponsorId = val;
                                    _syncActiveStorefront();
                                    setState(() => _loading = true);
                                    await _loadProducts();
                                    if (!mounted) return;
                                    setState(() => _loading = false);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                        ),
                        _buildBrandingPreview(),
                        Expanded(
                          child: _products.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          size: 56,
                                          color: AppColors.primary.withValues(alpha: 0.4),
                                        ),
                                        const SizedBox(height: 14),
                                        Text(
                                          'No products yet',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Add your first reward gift. Active products make your storefront visible in Lead Market.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.nunito(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        ElevatedButton.icon(
                                          onPressed: _createProduct,
                                          icon: const Icon(Icons.add),
                                          label: const Text('Add product'),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _products.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, idx) {
                                    final p = _products[idx];
                                    final name = (p['name'] ?? '').toString();
                                    final stock =
                                        (p['stock_available'] as num?)?.toInt() ?? 0;
                                    final price =
                                        (p['price_coins'] as num?)?.toInt() ?? 0;
                                    final kind =
                                        (p['product_kind'] ?? 'unknown').toString();
                                    return Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF111827),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.06),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.card_giftcard,
                                            color: Colors.white70,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '$price coins • $stock left • $kind',
                                                  style: GoogleFonts.nunito(
                                                    color: Colors.white60,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
    );
  }
}
