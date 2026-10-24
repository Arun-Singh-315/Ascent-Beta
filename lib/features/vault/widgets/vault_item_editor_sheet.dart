import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../models/vault_item_model.dart';
import '../providers/vault_providers.dart';
import '../services/vault_pattern_extractor.dart';
import 'cred_card_visual.dart';

class VaultItemEditorSheet extends ConsumerStatefulWidget {
  const VaultItemEditorSheet({
    super.key,
    this.initialItem,
    this.initialCategory = VaultCategory.card,
  });

  final VaultItem? initialItem;
  final VaultCategory initialCategory;

  static Future<void> show(
    BuildContext context, {
    VaultItem? item,
    VaultCategory category = VaultCategory.card,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VaultItemEditorSheet(
        initialItem: item,
        initialCategory: item?.category ?? category,
      ),
    );
  }

  @override
  ConsumerState<VaultItemEditorSheet> createState() => _VaultItemEditorSheetState();
}

class _VaultItemEditorSheetState extends ConsumerState<VaultItemEditorSheet> {
  late VaultCategory _selectedCategory;
  final _titleController = TextEditingController();

  // Card fields
  final _cardholderController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _bankNameController = TextEditingController();
  CredCardSkin? _selectedSkin;

  // ID fields
  String _selectedIdType = 'Passport';
  final _idNumberController = TextEditingController();
  final _idHolderController = TextEditingController();

  // Login fields
  final _loginWebsiteController = TextEditingController();
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Document & Note fields
  final _noteContentController = TextEditingController();
  final List<String> _mediaPaths = [];

  bool _saving = false;
  String? _titleError;
  String? _cardError;
  String? _expiryError;
  String? _idError;
  String? _emailError;
  String? _loginError;
  String? _noteError;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    final item = widget.initialItem;
    if (item != null) {
      _titleController.text = item.title;
      _selectedCategory = item.category;
      _mediaPaths.addAll(item.mediaPaths);

      final f = item.fields;
      _cardholderController.text = f['cardholderName'] as String? ?? '';
      _cardNumberController.text = f['cardNumber'] as String? ?? '';
      _expiryController.text = f['expiry'] as String? ?? '';
      _cvvController.text = f['cvv'] as String? ?? '';
      _bankNameController.text = f['bankName'] as String? ?? '';
      final skinName = f['skin'] as String?;
      if (skinName != null) {
        try {
          _selectedSkin = CredCardSkin.values.firstWhere((s) => s.name == skinName);
        } catch (_) {}
      }

      _selectedIdType = f['docType'] as String? ?? 'Passport';
      _idNumberController.text = f['docNumber'] as String? ?? '';
      _idHolderController.text = f['holderName'] as String? ?? '';

      _loginWebsiteController.text = f['website'] as String? ?? '';
      _loginUsernameController.text = f['username'] as String? ?? '';
      _loginPasswordController.text = f['password'] as String? ?? '';

      _noteContentController.text = f['content'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cardholderController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _bankNameController.dispose();
    _idNumberController.dispose();
    _idHolderController.dispose();
    _loginWebsiteController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _noteContentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      // Copy into app's private sandbox
      final appDir = await getApplicationDocumentsDirectory();
      final vaultMediaDir = Directory(p.join(appDir.path, 'vault_media'));
      if (!vaultMediaDir.existsSync()) {
        vaultMediaDir.createSync(recursive: true);
      }

      final fileName = 'vault_${DateTime.now().millisecondsSinceEpoch}_${p.basename(picked.path)}';
      final savedFile = await File(picked.path).copy(p.join(vaultMediaDir.path, fileName));

      setState(() {
        _mediaPaths.add(savedFile.path);
      });
    } catch (_) {}
  }

  void _showSmartScanDialog() {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final g = ctx.glass;
        return AlertDialog(
          backgroundColor: ctx.isDark ? const Color(0xFF1E1E28) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: g.clay, size: 22),
              const SizedBox(width: AppSpace.s8),
              Text('Smart Auto-Capture', style: TextStyle(color: g.ink, fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste raw text from a card, SMS, or ID document. The smart extractor will detect card numbers, expiry dates, PAN or Aadhaar automatically.',
                style: TextStyle(fontSize: 12.5, color: g.inkMuted),
              ),
              const SizedBox(height: AppSpace.s12),
              TextField(
                controller: textController,
                maxLines: 4,
                style: TextStyle(color: g.ink, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Paste card info, SMS receipt, or ID details here...',
                  hintStyle: TextStyle(color: g.inkMuted, fontSize: 13),
                  filled: true,
                  fillColor: g.fill.withValues(alpha: 0.3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: g.line)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: g.clay),
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('Extract & Fill'),
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  _applyExtractedData(text);
                }
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _applyExtractedData(String raw) {
    final data = VaultPatternExtractor.extractPatterns(raw);
    HapticFeedback.mediumImpact();

    setState(() {
      if (data.cardNumber != null) {
        _selectedCategory = VaultCategory.card;
        _cardNumberController.text = data.cardNumber!;
        if (data.cardBrand != null) {
          _titleController.text = '${data.cardBrand!} Card';
        }
      }
      if (data.expiry != null) {
        _expiryController.text = data.expiry!;
      }
      if (data.cvv != null) {
        _cvvController.text = data.cvv!;
      }
      if (data.panNumber != null) {
        _selectedCategory = VaultCategory.idDoc;
        _selectedIdType = 'PAN Card';
        _idNumberController.text = data.panNumber!;
        if (_titleController.text.isEmpty) _titleController.text = 'PAN Card';
      }
      if (data.aadhaarNumber != null) {
        _selectedCategory = VaultCategory.idDoc;
        _selectedIdType = 'Aadhaar';
        _idNumberController.text = data.aadhaarNumber!;
        if (_titleController.text.isEmpty) _titleController.text = 'Aadhaar Card';
      }
      if (data.email != null) {
        _loginUsernameController.text = data.email!;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Details extracted and auto-filled!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool _validateInputs() {
    bool valid = true;
    setState(() {
      _titleError = null;
      _cardError = null;
      _expiryError = null;
      _idError = null;
      _emailError = null;
      _loginError = null;
      _noteError = null;
    });

    if (_titleController.text.trim().isEmpty) {
      setState(() => _titleError = 'Title cannot be left empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title'), behavior: SnackBarBehavior.floating),
      );
      valid = false;
    }

    if (_selectedCategory == VaultCategory.card) {
      final cardNum = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
      if (cardNum.isEmpty) {
        setState(() => _cardError = 'Card number cannot be left empty');
        valid = false;
      } else if (!VaultPatternExtractor.isValidLuhn(cardNum)) {
        setState(() => _cardError = 'Invalid card number (checksum failed)');
        valid = false;
      }
      final exp = _expiryController.text.trim();
      if (exp.isNotEmpty && !VaultPatternExtractor.isValidExpiry(exp)) {
        setState(() => _expiryError = 'Invalid expiry date (use MM/YY)');
        valid = false;
      }
    } else if (_selectedCategory == VaultCategory.idDoc) {
      final idNum = _idNumberController.text.trim();
      if (idNum.isEmpty) {
        setState(() => _idError = 'Document number cannot be left empty');
        valid = false;
      } else if (_selectedIdType == 'PAN Card' && !VaultPatternExtractor.isValidPan(idNum)) {
        setState(() => _idError = 'Invalid PAN format (e.g. ABCDE1234F)');
        valid = false;
      } else if (_selectedIdType == 'Aadhaar' && !VaultPatternExtractor.isValidAadhaar(idNum)) {
        setState(() => _idError = 'Invalid Aadhaar (12 digits, cannot start with 0/1)');
        valid = false;
      }
    } else if (_selectedCategory == VaultCategory.login) {
      final user = _loginUsernameController.text.trim();
      final pwd = _loginPasswordController.text.trim();
      final web = _loginWebsiteController.text.trim();
      if (user.isEmpty && pwd.isEmpty && web.isEmpty) {
        setState(() => _loginError = 'Provide username, password, or service');
        valid = false;
      } else if (user.contains('@') && !VaultPatternExtractor.isValidEmail(user)) {
        setState(() => _emailError = 'Please check email format');
        valid = false;
      }
    } else if (_selectedCategory == VaultCategory.note) {
      final content = _noteContentController.text.trim();
      if (content.isEmpty && _mediaPaths.isEmpty) {
        setState(() => _noteError = 'Note content or attachment cannot be left empty');
        valid = false;
      }
    }

    return valid;
  }

  Future<void> _save() async {
    if (!_validateInputs() || _saving) return;

    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    final title = _titleController.text.trim();
    String? subtitle;
    final Map<String, dynamic> fields = {};

    switch (_selectedCategory) {
      case VaultCategory.card:
        final rawNum = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
        final brand = VaultPatternExtractor.detectCardBrand(rawNum);
        final last4 = rawNum.length >= 4 ? rawNum.substring(rawNum.length - 4) : '';
        subtitle = '$brand •••• $last4';
        fields['cardholderName'] = _cardholderController.text.trim();
        fields['cardNumber'] = rawNum;
        fields['expiry'] = _expiryController.text.trim();
        fields['cvv'] = _cvvController.text.trim();
        fields['bankName'] = _bankNameController.text.trim();
        fields['cardBrand'] = brand;
        if (_selectedSkin != null) {
          fields['skin'] = _selectedSkin!.name;
        }
        break;

      case VaultCategory.idDoc:
        final docNum = _idNumberController.text.trim();
        subtitle = '$_selectedIdType • ${docNum.length > 4 ? docNum.substring(docNum.length - 4) : docNum}';
        fields['docType'] = _selectedIdType;
        fields['docNumber'] = docNum;
        fields['holderName'] = _idHolderController.text.trim();
        break;

      case VaultCategory.login:
        final user = _loginUsernameController.text.trim();
        subtitle = user.isNotEmpty ? user : _loginWebsiteController.text.trim();
        fields['website'] = _loginWebsiteController.text.trim();
        fields['username'] = user;
        fields['password'] = _loginPasswordController.text;
        break;

      case VaultCategory.document:
        subtitle = '${_mediaPaths.length} attachment(s)';
        fields['notes'] = _noteContentController.text.trim();
        break;

      case VaultCategory.note:
        subtitle = 'Confidential Note';
        fields['content'] = _noteContentController.text.trim();
        break;
    }

    final storage = ref.read(vaultStorageServiceProvider);

    if (widget.initialItem != null) {
      final updated = widget.initialItem!.copyWith(
        title: title,
        category: _selectedCategory,
        subtitle: subtitle,
        fields: fields,
        mediaPaths: _mediaPaths,
        updatedAt: DateTime.now(),
      );
      await storage.updateItem(updated);
    } else {
      final newItem = VaultItem(
        title: title,
        category: _selectedCategory,
        subtitle: subtitle,
        fields: fields,
        mediaPaths: _mediaPaths,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await storage.insertItem(newItem);
    }

    HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = context.isDark;

    return Container(
      padding: EdgeInsets.only(
        top: AppSpace.s16,
        left: AppSpace.s16,
        right: AppSpace.s16,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpace.s20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161622) : const Color(0xFFF9FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: g.line),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HANDLE & HEADER ──────────────────────────────────────────
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: g.inkMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.initialItem != null ? 'Edit Vault Item' : 'New Vault Item',
                    style: AscentTextStyles.homeTitle.copyWith(
                      color: g.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showSmartScanDialog,
                    icon: Icon(Icons.auto_awesome_rounded, color: g.clay, size: 18),
                    label: Text('Auto-Fill', style: TextStyle(color: g.clay, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s12),

              // ── CATEGORY PICKER ──────────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: VaultCategory.values.map((cat) {
                    final selected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: selected,
                        label: Text(cat.shortName),
                        selectedColor: g.clay.withValues(alpha: 0.18),
                        checkmarkColor: g.clay,
                        labelStyle: TextStyle(
                          color: selected ? g.clay : g.inkMuted,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12.5,
                        ),
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSpace.s16),

              // ── TITLE FIELD ──────────────────────────────────────────────
              _buildTextField(
                controller: _titleController,
                label: 'Title',
                hint: _getCategoryTitleHint(_selectedCategory),
                icon: Icons.label_outline_rounded,
                errorText: _titleError,
                g: g,
              ),
              const SizedBox(height: AppSpace.s12),

              // ── DYNAMIC CATEGORY FIELDS ──────────────────────────────────
              if (_selectedCategory == VaultCategory.card) ...[
                _buildCardForm(g),
              ] else if (_selectedCategory == VaultCategory.idDoc) ...[
                _buildIdDocForm(g),
              ] else if (_selectedCategory == VaultCategory.login) ...[
                _buildLoginForm(g),
              ] else ...[
                _buildNoteForm(g),
              ],

              const SizedBox(height: AppSpace.s16),

              // ── ATTACHMENTS (Images / Scans) ─────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attachments & Scans (${_mediaPaths.length})',
                    style: AscentTextStyles.displaySmall.copyWith(color: g.ink, fontSize: 14),
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        icon: Icon(Icons.camera_alt_outlined, color: g.clay, size: 20),
                        onPressed: () => _pickImage(ImageSource.camera),
                        tooltip: 'Take Photo',
                      ),
                      IconButton(
                        icon: Icon(Icons.photo_library_outlined, color: g.clay, size: 20),
                        onPressed: () => _pickImage(ImageSource.gallery),
                        tooltip: 'Choose from Gallery',
                      ),
                    ],
                  ),
                ],
              ),
              if (_mediaPaths.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s8),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mediaPaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, idx) {
                      final path = _mediaPaths[idx];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(path),
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 64,
                                height: 64,
                                color: g.line,
                                child: const Icon(Icons.broken_image, size: 20),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () => setState(() => _mediaPaths.removeAt(idx)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: AppSpace.s24),

              // ── SAVE BUTTON ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: g.clay,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.lock_rounded, size: 18),
                  label: Text(
                    widget.initialItem != null ? 'Update Item' : 'Secure & Save to Vault',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCategoryTitleHint(VaultCategory category) {
    switch (category) {
      case VaultCategory.card:
        return 'e.g. HDFC Regalia Gold, ICICI Coral';
      case VaultCategory.idDoc:
        return 'e.g. Passport, Aadhaar Card, Driving License';
      case VaultCategory.login:
        return 'e.g. Google Account, GitHub, Work Portal';
      case VaultCategory.document:
        return 'e.g. House Rental Agreement, Medical Insurance';
      case VaultCategory.note:
        return 'e.g. Secret Recovery Phrase, Locker Code';
    }
  }

  Widget _buildCardForm(AscentGlass g) {
    final previewBank = _bankNameController.text.trim().isNotEmpty
        ? _bankNameController.text.trim()
        : (_titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Ascent Bank');
    final previewHolder = _cardholderController.text.trim().isNotEmpty
        ? _cardholderController.text.trim()
        : 'YOUR NAME';
    final previewNumber = _cardNumberController.text.trim();
    final previewExpiry = _expiryController.text.trim().isNotEmpty
        ? _expiryController.text.trim()
        : '12/28';
    final detectedBrand = VaultPatternExtractor.detectCardBrand(previewNumber);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── LIVE CRED-GRADE CARD PREVIEW ──────────────────────────────────
        CredCardVisual(
          bankName: previewBank,
          cardTier: 'Signature',
          cardholderName: previewHolder,
          cardNumber: previewNumber,
          expiryDate: previewExpiry,
          cardBrand: detectedBrand,
          skin: _selectedSkin,
          showActions: false,
        ),
        const SizedBox(height: AppSpace.s12),

        // ── LUXURY SKIN SELECTOR ──────────────────────────────────────────
        Text(
          'Card Luxury Theme / Skin',
          style: TextStyle(color: g.inkMuted, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpace.s6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  selected: _selectedSkin == null,
                  label: const Text('Auto-Bank'),
                  selectedColor: g.clay.withValues(alpha: 0.2),
                  checkmarkColor: g.clay,
                  labelStyle: TextStyle(
                    color: _selectedSkin == null ? g.clay : g.inkMuted,
                    fontSize: 11.5,
                    fontWeight: _selectedSkin == null ? FontWeight.w700 : FontWeight.w500,
                  ),
                  onSelected: (_) => setState(() => _selectedSkin = null),
                ),
              ),
              ...CredCardSkin.values.map((skin) {
                final isSelected = _selectedSkin == skin;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    selected: isSelected,
                    avatar: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: skin.gradientColors),
                        border: Border.all(color: skin.borderColor, width: 1),
                      ),
                    ),
                    label: Text(skin.label),
                    selectedColor: g.clay.withValues(alpha: 0.2),
                    checkmarkColor: g.clay,
                    labelStyle: TextStyle(
                      color: isSelected ? g.clay : g.inkMuted,
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (_) => setState(() => _selectedSkin = skin),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s14),

        _buildTextField(
          controller: _bankNameController,
          label: 'Bank / Issuer',
          hint: 'e.g. HDFC Bank, SBI, Chase',
          icon: Icons.account_balance_outlined,
          g: g,
        ),
        const SizedBox(height: AppSpace.s12),
        _buildTextField(
          controller: _cardNumberController,
          label: 'Card Number',
          hint: '16 digits (spaces optional)',
          icon: Icons.credit_card_rounded,
          keyboardType: TextInputType.number,
          errorText: _cardError,
          g: g,
        ),
        const SizedBox(height: AppSpace.s12),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _expiryController,
                label: 'Expiry',
                hint: 'MM/YY',
                icon: Icons.calendar_today_outlined,
                keyboardType: TextInputType.datetime,
                errorText: _expiryError,
                g: g,
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: _buildTextField(
                controller: _cvvController,
                label: 'CVV',
                hint: '3 or 4 digits',
                icon: Icons.security_rounded,
                keyboardType: TextInputType.number,
                obscureText: true,
                g: g,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s12),
        _buildTextField(
          controller: _cardholderController,
          label: 'Cardholder Name',
          hint: 'Name as printed on card',
          icon: Icons.person_outline_rounded,
          g: g,
        ),
      ],
    );
  }

  Widget _buildIdDocForm(AscentGlass g) {
    const docTypes = ['Passport', 'Aadhaar', 'PAN Card', 'Driving License', 'Voter ID', 'National ID'];
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: docTypes.contains(_selectedIdType) ? _selectedIdType : docTypes.first,
          decoration: InputDecoration(
            labelText: 'Document Type',
            filled: true,
            fillColor: g.fill.withValues(alpha: 0.3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: g.line)),
          ),
          items: docTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedIdType = val);
          },
        ),
        const SizedBox(height: AppSpace.s12),
        _buildTextField(
          controller: _idNumberController,
          label: 'Document Number',
          hint: 'e.g. Document or identification number',
          icon: Icons.pin_outlined,
          errorText: _idError,
          g: g,
        ),
        const SizedBox(height: AppSpace.s12),
        _buildTextField(
          controller: _idHolderController,
          label: 'Full Name on Document',
          hint: 'Name as printed on ID',
          icon: Icons.person_outline_rounded,
          g: g,
        ),
      ],
    );
  }

  Widget _buildLoginForm(AscentGlass g) {
    final password = _loginPasswordController.text;
    final strength = VaultPatternExtractor.calculatePasswordStrength(password);

    return Column(
      children: [
        _buildTextField(
          controller: _loginWebsiteController,
          label: 'Website / App',
          hint: 'e.g. github.com, mywork.portal.com',
          icon: Icons.language_rounded,
          g: g,
        ),
        const SizedBox(height: AppSpace.s12),
        _buildTextField(
          controller: _loginUsernameController,
          label: 'Username / Email',
          hint: 'e.g. user@domain.com',
          icon: Icons.alternate_email_rounded,
          errorText: _emailError ?? _loginError,
          g: g,
        ),
        const SizedBox(height: AppSpace.s12),
        _buildTextField(
          controller: _loginPasswordController,
          label: 'Password',
          hint: 'Enter or generate password',
          icon: Icons.lock_outline_rounded,
          onChanged: (_) => setState(() {}),
          g: g,
        ),
        const SizedBox(height: AppSpace.s8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                password.isEmpty
                    ? 'Password strength'
                    : (strength >= 80 ? 'Strong password' : (strength >= 50 ? 'Medium password' : 'Weak password')),
                style: TextStyle(
                  fontSize: 11,
                  color: strength >= 80 ? g.sage : (strength >= 50 ? g.amber : g.coral),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              icon: Icon(Icons.generating_tokens_outlined, size: 16, color: g.clay),
              label: Text('Generate Strong', style: TextStyle(color: g.clay, fontSize: 12)),
              onPressed: () {
                final generated = VaultPatternExtractor.generatePassword(length: 16);
                HapticFeedback.lightImpact();
                setState(() {
                  _loginPasswordController.text = generated;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoteForm(AscentGlass g) {
    return _buildTextField(
      controller: _noteContentController,
      label: 'Secure Content',
      hint: 'Type your secret notes, recovery codes, or locker combinations here...',
      icon: Icons.notes_rounded,
      maxLines: 5,
      errorText: _noteError,
      g: g,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required AscentGlass g,
    TextInputType? keyboardType,
    bool obscureText = false,
    int maxLines = 1,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(color: g.ink, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: g.inkMuted, fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: g.inkMuted.withValues(alpha: 0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: g.inkMuted, size: 20),
        errorText: errorText,
        filled: true,
        fillColor: g.fill.withValues(alpha: 0.25),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: g.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: g.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: g.clay, width: 1.5)),
      ),
    );
  }
}
