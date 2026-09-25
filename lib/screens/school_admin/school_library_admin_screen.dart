import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/school_library_item.dart';
import '../../providers/school_course_provider.dart';
import '../../providers/school_library_provider.dart';

/// School admin UI for uploading / linking school-scoped library resources.
class SchoolLibraryAdminScreen extends StatefulWidget {
  const SchoolLibraryAdminScreen({super.key});

  @override
  State<SchoolLibraryAdminScreen> createState() =>
      _SchoolLibraryAdminScreenState();
}

class _SchoolLibraryAdminScreenState extends State<SchoolLibraryAdminScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final school = context.read<SchoolCourseProvider>();
    if (!school.hasSchool) {
      await school.initialize();
    }
    final schoolId = school.schoolId;
    if (schoolId == null || !mounted) return;
    await context.read<SchoolLibraryProvider>().loadForSchool(
          schoolId: schoolId,
          publishedOnly: false,
        );
  }

  Future<void> _refresh() async {
    await context.read<SchoolLibraryProvider>().refresh(publishedOnly: false);
  }

  IconData _iconFor(SchoolLibraryResourceType type) {
    switch (type) {
      case SchoolLibraryResourceType.videoFile:
        return Icons.videocam_rounded;
      case SchoolLibraryResourceType.youtube:
        return Icons.smart_display_rounded;
      case SchoolLibraryResourceType.pdf:
        return Icons.picture_as_pdf_rounded;
      case SchoolLibraryResourceType.image:
        return Icons.image_rounded;
      case SchoolLibraryResourceType.link:
        return Icons.link_rounded;
      case SchoolLibraryResourceType.document:
        return Icons.description_rounded;
    }
  }

  Future<void> _confirmDelete(SchoolLibraryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete resource?'),
        content: Text('Remove "${item.title}" from the school library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<SchoolLibraryProvider>().delete(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _editItem(SchoolLibraryItem item) async {
    final titleCtrl = TextEditingController(text: item.title);
    final descCtrl = TextEditingController(text: item.description ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit resource'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final title = titleCtrl.text.trim();
    final description = descCtrl.text.trim();
    titleCtrl.dispose();
    descCtrl.dispose();
    if (saved != true || !mounted) return;
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }
    try {
      await context.read<SchoolLibraryProvider>().updateDetails(
            item,
            title: title,
            description: description,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddSheet() {
    final schoolId = context.read<SchoolCourseProvider>().schoolId;
    if (schoolId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddResourceSheet(schoolId: schoolId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final school = context.watch<SchoolCourseProvider>();
    final lib = context.watch<SchoolLibraryProvider>();

    if (!school.hasSchool) {
      return Scaffold(
        appBar: AppBar(title: const Text('School Library')),
        body: const Center(child: Text('No school linked to this account.')),
      );
    }

    if (!school.isSchoolAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('School Library')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'School Library Admin is only available to school admins.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final usage = lib.usage;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('School Library'),
            Text(
              school.schoolName ?? 'Your School',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: lib.loading ? null : _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add resource'),
        backgroundColor: AppColors.primary,
      ),
      body: lib.loading && lib.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                children: [
                  if (usage != null) _QuotaCard(usage: usage),
                  if (lib.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        lib.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (lib.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(
                        child: Text(
                          'No resources yet.\nAdd a file, YouTube video, or link.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...lib.items.map((item) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withOpacity(0.15),
                            child: Icon(
                              _iconFor(item.resourceType),
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              item.resourceType.label,
                              if (item.sizeLabel.isNotEmpty) item.sizeLabel,
                              item.isPublished ? 'Published' : 'Draft',
                            ].join(' · '),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await _editItem(item);
                              } else if (v == 'publish') {
                                try {
                                  await context
                                      .read<SchoolLibraryProvider>()
                                      .togglePublished(item);
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } else if (v == 'delete') {
                                await _confirmDelete(item);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'publish',
                                child: Text(
                                  item.isPublished ? 'Unpublish' : 'Publish',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _QuotaCard extends StatelessWidget {
  final SchoolLibraryUsage usage;
  const _QuotaCard({required this.usage});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Storage ${usage.usedLabel} / ${usage.maxLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: usage.usedFraction,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: usage.usedFraction > 0.9
                    ? Colors.orange
                    : AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${usage.itemCount} items · ${usage.remainingLabel} free · '
              'max ${usage.maxFileLabel}/file',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tip: use YouTube links for long videos to save storage.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddResourceSheet extends StatefulWidget {
  final String schoolId;
  const _AddResourceSheet({required this.schoolId});

  @override
  State<_AddResourceSheet> createState() => _AddResourceSheetState();
}

class _AddResourceSheetState extends State<_AddResourceSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  String _mode = 'youtube'; // youtube | link | file
  bool _publish = true;
  bool _saving = false;
  PlatformFile? _picked;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4',
        'mov',
        'webm',
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'gif',
        'webp',
        'doc',
        'docx',
        'ppt',
        'pptx',
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file bytes')),
      );
      return;
    }
    setState(() {
      _picked = f;
      if (_titleCtrl.text.trim().isEmpty) {
        _titleCtrl.text = f.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      }
    });
  }

  String? _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    return null;
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<SchoolLibraryProvider>();
    try {
      if (_mode == 'file') {
        final file = _picked;
        if (file == null || file.bytes == null) {
          throw Exception('Pick a file to upload');
        }
        await provider.addUpload(
          schoolId: widget.schoolId,
          title: title,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          bytes: file.bytes!,
          fileName: file.name,
          mimeType: file.extension != null
              ? _guessMime(file.name)
              : null,
          isPublished: _publish,
        );
      } else if (_mode == 'youtube') {
        await provider.addLinkOrYoutube(
          schoolId: widget.schoolId,
          title: title,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          type: SchoolLibraryResourceType.youtube,
          youtubeInput: _urlCtrl.text.trim(),
          isPublished: _publish,
        );
      } else {
        await provider.addLinkOrYoutube(
          schoolId: widget.schoolId,
          title: title,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          type: SchoolLibraryResourceType.link,
          externalUrl: _urlCtrl.text.trim(),
          isPublished: _publish,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resource added')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add library resource',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'youtube', label: Text('YouTube')),
                ButtonSegment(value: 'link', label: Text('Link')),
                ButtonSegment(value: 'file', label: Text('Upload')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_mode == 'file') ...[
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _picked == null
                      ? 'Choose file (video / PDF / image / doc)'
                      : _picked!.name,
                ),
              ),
            ] else
              TextField(
                controller: _urlCtrl,
                decoration: InputDecoration(
                  labelText: _mode == 'youtube'
                      ? 'YouTube URL or video ID'
                      : 'https://…',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publish immediately'),
              value: _publish,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _publish = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
