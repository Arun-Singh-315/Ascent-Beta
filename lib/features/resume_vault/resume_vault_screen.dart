import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' as drift;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/skeleton_shimmer.dart';

class ResumeVaultScreen extends ConsumerStatefulWidget {
  const ResumeVaultScreen({super.key});

  @override
  ConsumerState<ResumeVaultScreen> createState() => _ResumeVaultScreenState();
}

class _ResumeVaultScreenState extends ConsumerState<ResumeVaultScreen> {
  void _openUploadSheet([Resume? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _UploadResumeSheet(existing: existing),
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _copyPath(String path) {
    Clipboard.setData(ClipboardData(text: path));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resume file path copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openFile(Resume resume) async {
    final ext = p.extension(resume.filePath).toLowerCase();
    if (ext == '.pdf') {
      showDialog(
        context: context,
        useSafeArea: false,
        builder: (ctx) => PdfPreviewModal(
          filePath: resume.filePath,
          title: resume.versionLabel,
        ),
      );
    } else {
      final res = await OpenFilex.open(resume.filePath);
      if (res.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening file: ${res.message}')),
        );
      }
    }
  }

  void _shareResume(Resume resume) {
    SharePlus.instance.share(
      ShareParams(
        files: [XFile(resume.filePath)],
        text: resume.versionLabel,
      ),
    );
  }

  void _confirmDelete(Resume resume) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Delete Resume Version?',
                style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "${resume.versionLabel}"? This cannot be undone.',
                textAlign: TextAlign.center,
                style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AscentButton.destructive(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AscentButton.primary(
                      label: 'Delete',
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          final file = File(resume.filePath);
                          if (await file.exists()) {
                            await file.delete();
                          }
                        } catch (_) {}
                        await ref.read(resumeDaoProvider).deleteResume(resume.id);
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
  }

  @override
  Widget build(BuildContext context) {
    final resumeDao = ref.watch(resumeDaoProvider);
    final resumesStream = resumeDao.watchAllResumes();

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        backgroundColor: context.bgBase,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Resume Vault',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.upload_file_rounded, color: context.accentPrimary, size: 26),
            tooltip: 'Upload Version',
            onPressed: () => _openUploadSheet(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Resume>>(
        stream: resumesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: SkeletonShimmer(height: 200),
            );
          }

          final resumes = snapshot.data ?? [];

          if (resumes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: context.accentPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        color: context.accentPrimary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Resumes in Vault',
                      style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Store and track multiple versions of your resume tailored for different roles and companies.',
                      textAlign: TextAlign.center,
                      style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                    ),
                    const SizedBox(height: 24),
                    AscentButton.primary(
                      label: 'Upload Resume Version',
                      icon: Icons.upload_file_rounded,
                      onPressed: () => _openUploadSheet(),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: resumes.length,
            itemBuilder: (context, index) {
              final resume = resumes[index];
              final uploadedStr = DateFormat.yMMMd().format(resume.uploadedAt);
              final ext = p.extension(resume.filePath).replaceAll('.', '').toUpperCase();

              return AscentCard(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                onTap: () => _openFile(resume),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Format badge, tailoring chip, popup menu
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.accentPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ext.isEmpty ? 'DOC' : ext,
                            style: AscentTextStyles.monoCode.copyWith(
                              color: context.accentPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (resume.tailoredForCompany?.isNotEmpty == true) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.accentSecondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Tailored for ${resume.tailoredForCompany}',
                              style: AscentTextStyles.labelSmall.copyWith(
                                color: context.accentSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Spacer(),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded, size: 18, color: context.textMuted),
                          padding: EdgeInsets.zero,
                          onSelected: (val) {
                            if (val == 'open') _openFile(resume);
                            if (val == 'share') _shareResume(resume);
                            if (val == 'copy') _copyPath(resume.filePath);
                            if (val == 'edit') _openUploadSheet(resume);
                            if (val == 'delete') _confirmDelete(resume);
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'open', child: Text('Open / Preview')),
                            const PopupMenuItem(value: 'share', child: Text('Share File')),
                            const PopupMenuItem(value: 'copy', child: Text('Copy File Path')),
                            const PopupMenuItem(value: 'edit', child: Text('Edit Info')),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete Version', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Version Label
                    Text(
                      resume.versionLabel,
                      style: AscentTextStyles.headlineMedium.copyWith(
                        color: context.textPrimary,
                        fontSize: 17,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Inline Notes Editor with blur autosave (§10)
                    _InlineResumeNotes(
                      resume: resume,
                      onSaveNotes: (newNotes) async {
                        await ref.read(resumeDaoProvider).updateResume(
                          ResumeTableCompanion(
                            id: drift.Value(resume.id),
                            notes: drift.Value(newNotes.isEmpty ? null : newNotes),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Footer meta & actions
                    Row(
                      children: [
                        Icon(Icons.insert_drive_file_outlined, size: 14, color: context.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          _formatFileSize(resume.fileSize),
                          style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.access_time_rounded, size: 14, color: context.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          uploadedStr,
                          style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _openFile(resume),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.visibility_outlined, size: 14, color: context.accentPrimary),
                                const SizedBox(width: 4),
                                Text(
                                  'Preview',
                                  style: AscentTextStyles.labelSmall.copyWith(
                                    color: context.accentPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _shareResume(resume),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.share_rounded, size: 14, color: context.accentPrimary),
                                const SizedBox(width: 4),
                                Text(
                                  'Share',
                                  style: AscentTextStyles.labelSmall.copyWith(
                                    color: context.accentPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upload / Edit Resume Sheet
// ---------------------------------------------------------------------------

class _UploadResumeSheet extends ConsumerStatefulWidget {
  final Resume? existing;

  const _UploadResumeSheet({this.existing});

  @override
  ConsumerState<_UploadResumeSheet> createState() => _UploadResumeSheetState();
}

class _UploadResumeSheetState extends ConsumerState<_UploadResumeSheet> {
  final _labelController = TextEditingController();
  final _companyController = TextEditingController();
  final _notesController = TextEditingController();
  String? _pickedFilePath;
  int? _pickedFileSize;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final r = widget.existing!;
      _labelController.text = r.versionLabel;
      _companyController.text = r.tailoredForCompany ?? '';
      _notesController.text = r.notes ?? '';
      _pickedFilePath = r.filePath;
      _pickedFileSize = r.fileSize;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _companyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );
      if (picked != null && picked.path != null) {
        final originalFile = File(picked.path!);
        final fileName = picked.name;
        final fileSize = await originalFile.length();

        // Safe copy to app documents directory
        final appDocDir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final safePath = p.join(appDocDir.path, 'resumes', '${timestamp}_$fileName');

        final targetDir = Directory(p.dirname(safePath));
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }

        await originalFile.copy(safePath);

        setState(() {
          _pickedFilePath = safePath;
          _pickedFileSize = fileSize;
          if (_labelController.text.isEmpty) {
            _labelController.text = p.basenameWithoutExtension(fileName);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File selection failed: $e')),
        );
      }
    }
  }

  Future<void> _useSampleTemplate() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(p.join(appDocDir.path, 'resumes'));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final templatePath = p.join(targetDir.path, 'starter_resume_$timestamp.pdf');
      final file = File(templatePath);
      await file.writeAsString(
        '%PDF-1.4\n% Ascent Standard Engineering Resume\n1 0 obj\n<< /Title (Software Engineer Resume) /Author (Ascent User) >>\nendobj\n%%EOF',
      );
      final size = await file.length();
      setState(() {
        _pickedFilePath = templatePath;
        _pickedFileSize = size;
        if (_labelController.text.isEmpty) {
          _labelController.text = 'Software Engineer (Standard)';
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template generation failed: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a version label')),
      );
      return;
    }

    if (_pickedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a resume file (PDF/DOCX)')),
      );
      return;
    }

    setState(() => _isUploading = true);
    final resumeDao = ref.read(resumeDaoProvider);
    final company = _companyController.text.trim().isEmpty ? null : _companyController.text.trim();
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    if (widget.existing != null) {
      await resumeDao.updateResume(
        ResumeTableCompanion(
          id: drift.Value(widget.existing!.id),
          versionLabel: drift.Value(label),
          filePath: drift.Value(_pickedFilePath!),
          fileSize: drift.Value(_pickedFileSize),
          tailoredForCompany: drift.Value(company),
          notes: drift.Value(notes),
        ),
      );
    } else {
      await resumeDao.insertResume(
        ResumeTableCompanion.insert(
          versionLabel: label,
          filePath: _pickedFilePath!,
          fileSize: drift.Value(_pickedFileSize),
          tailoredForCompany: drift.Value(company),
          notes: drift.Value(notes),
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existing != null ? 'Edit Resume Version' : 'Upload Resume Version',
                  style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // File Selector Box
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.bgBase,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _pickedFilePath != null ? context.accentPrimary : context.divider,
                    width: _pickedFilePath != null ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _pickedFilePath != null
                          ? Icons.check_circle_rounded
                          : Icons.cloud_upload_outlined,
                      color: _pickedFilePath != null ? context.stateSuccess : context.accentPrimary,
                      size: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pickedFilePath != null
                                ? p.basename(_pickedFilePath!)
                                : 'Select Resume File (PDF, DOCX)',
                            style: AscentTextStyles.bodyMedium.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _pickedFilePath != null
                                ? 'Safely copied to Ascent local vault'
                                : 'Tap to browse storage',
                            style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: Icon(Icons.auto_awesome_rounded, size: 14, color: context.accentPrimary),
                label: Text(
                  'Or generate starter template',
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: context.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _useSampleTemplate,
              ),
            ),
            const SizedBox(height: 10),

            // Version Label
            Text(
              'Version Label *',
              style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _labelController,
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. v2 - Backend & Distributed Systems',
                hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                filled: true,
                fillColor: context.bgBase,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Tailored for company
            Text(
              'Tailored for Company (Optional)',
              style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _companyController,
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Google, Stripe, Datadog',
                hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                filled: true,
                fillColor: context.bgBase,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Version Notes
            Text(
              'Key Highlights & Changes',
              style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Rewrote lead bullet for latency reduction; highlighted Kubernetes expertise.',
                hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                filled: true,
                fillColor: context.bgBase,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: AscentButton.destructive(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AscentButton.primary(
                    label: widget.existing != null ? 'Update' : 'Save to Vault',
                    loading: _isUploading,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inline Resume Notes Editor with blur autosave (§10)
// ---------------------------------------------------------------------------

class _InlineResumeNotes extends StatefulWidget {
  final Resume resume;
  final ValueChanged<String> onSaveNotes;

  const _InlineResumeNotes({
    required this.resume,
    required this.onSaveNotes,
  });

  @override
  State<_InlineResumeNotes> createState() => _InlineResumeNotesState();
}

class _InlineResumeNotesState extends State<_InlineResumeNotes> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.resume.notes ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        final text = _controller.text.trim();
        if (text != (widget.resume.notes ?? '')) {
          widget.onSaveNotes(text);
        }
        if (mounted) setState(() => _isEditing = false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _InlineResumeNotes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resume.notes != widget.resume.notes && !_focusNode.hasFocus) {
      _controller.text = widget.resume.notes ?? '';
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        maxLines: 3,
        style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
        decoration: InputDecoration(
          hintText: 'Add notes / highlights (auto-saves on blur)...',
          hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
          filled: true,
          fillColor: context.bgBase,
          contentPadding: const EdgeInsets.all(12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: context.accentPrimary),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: context.accentPrimary, width: 1.5),
          ),
        ),
      );
    }

    final hasNotes = widget.resume.notes?.isNotEmpty == true;
    return InkWell(
      onTap: () => setState(() => _isEditing = true),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.bgBase.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.divider.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notes_rounded, size: 15, color: context.accentPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasNotes
                    ? widget.resume.notes!
                    : 'Tap to add notes / key highlights (auto-saves on blur)',
                style: AscentTextStyles.bodySmall.copyWith(
                  color: hasNotes ? context.textSecondary : context.textMuted,
                  fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.edit_outlined, size: 14, color: context.textMuted.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fullscreen PDF Preview Modal with page indicator & controls (§10)
// ---------------------------------------------------------------------------

class PdfPreviewModal extends StatefulWidget {
  final String filePath;
  final String title;

  const PdfPreviewModal({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  State<PdfPreviewModal> createState() => _PdfPreviewModalState();
}

class _PdfPreviewModalState extends State<PdfPreviewModal> {
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isReady = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: context.bgBase,
        appBar: AppBar(
          backgroundColor: context.bgSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: AscentTextStyles.headlineMedium.copyWith(
                  color: context.textPrimary,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_totalPages > 0)
                Text(
                  'Page ${_currentPage + 1} of $_totalPages',
                  style: AscentTextStyles.caption.copyWith(color: context.textMuted),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share Resume',
              onPressed: () {
                SharePlus.instance.share(
                  ShareParams(
                    files: [XFile(widget.filePath)],
                    text: widget.title,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            PDFView(
              filePath: widget.filePath,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              pageSnap: true,
              onRender: (pages) {
                if (mounted) {
                  setState(() {
                    _totalPages = pages ?? 0;
                    _isReady = true;
                  });
                }
              },
              onError: (error) {
                if (mounted) {
                  setState(() {
                    _errorMessage = error.toString();
                  });
                }
              },
              onPageError: (page, error) {
                if (mounted) {
                  setState(() {
                    _errorMessage = '$page: ${error.toString()}';
                  });
                }
              },
              onPageChanged: (int? page, int? total) {
                if (mounted) {
                  setState(() {
                    _currentPage = page ?? 0;
                    _totalPages = total ?? 0;
                  });
                }
              },
            ),
            if (!_isReady && _errorMessage.isEmpty)
              const Center(child: CircularProgressIndicator()),
            if (_errorMessage.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded, color: context.stateDanger, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to render PDF preview',
                        style: AscentTextStyles.headlineMedium.copyWith(color: context.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      AscentButton.primary(
                        label: 'Open Externally',
                        onPressed: () => OpenFilex.open(widget.filePath),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
