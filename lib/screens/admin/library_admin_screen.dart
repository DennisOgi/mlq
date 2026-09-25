import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../constants/app_constants.dart';
import '../../models/library_video_model.dart';
import '../../services/library_service.dart';

class LibraryAdminScreen extends StatefulWidget {
  const LibraryAdminScreen({super.key});

  @override
  State<LibraryAdminScreen> createState() => _LibraryAdminScreenState();
}

class _LibraryAdminScreenState extends State<LibraryAdminScreen> {
  final _svc = LibraryService.instance;
  bool _loading = true;
  String? _error;
  List<LibraryVideo> _videos = [];
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _videos = await _svc.getAllVideosAdmin();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  List<LibraryVideo> get _shown {
    if (_filter == 'All') return _videos;
    if (_filter == 'Published') return _videos.where((v) => v.isPublished).toList();
    if (_filter == 'Draft') return _videos.where((v) => !v.isPublished).toList();
    if (_filter == 'Featured') return _videos.where((v) => v.isFeatured).toList();
    return _videos;
  }

  Future<void> _delete(LibraryVideo v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete video?'),
        content: Text('Remove "${v.title}" from the library?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _svc.deleteVideo(v.id);
    setState(() => _videos.removeWhere((x) => x.id == v.id));
  }

  Future<void> _togglePublish(LibraryVideo v) async {
    final updated = await _svc.updateVideo(v.copyWith(isPublished: !v.isPublished));
    final idx = _videos.indexWhere((x) => x.id == v.id);
    if (idx != -1) setState(() => _videos[idx] = updated);
  }

  Future<void> _toggleFeatured(LibraryVideo v) async {
    final nowFeatured = !v.isFeatured;
    await _svc.setFeatured(v.id, featured: nowFeatured);
    // Reflect locally
    setState(() {
      for (var i = 0; i < _videos.length; i++) {
        if (_videos[i].isFeatured && _videos[i].id != v.id) {
          _videos[i] = _videos[i].copyWith(isFeatured: false, featuredDate: null);
        }
      }
      final idx = _videos.indexWhere((x) => x.id == v.id);
      if (idx != -1) {
        final today = DateTime.now().toIso8601String().split('T').first;
        _videos[idx] = _videos[idx].copyWith(
          isFeatured: nowFeatured,
          featuredDate: nowFeatured ? today : null,
        );
      }
    });
  }

  void _showForm([LibraryVideo? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VideoForm(
        initial: existing,
        onSave: (v) async {
          if (existing == null) {
            final created = await _svc.createVideo(v);
            setState(() => _videos.insert(0, created));
          } else {
            final updated = await _svc.updateVideo(v);
            final idx = _videos.indexWhere((x) => x.id == v.id);
            if (idx != -1) setState(() => _videos[idx] = updated);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Library Management',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showForm(),
            tooltip: 'Add video',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            color: AppColors.primary.withOpacity(0.06),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Stat('Total', _videos.length.toString()),
                    _Stat('Published',
                        _videos.where((v) => v.isPublished).length.toString()),
                    _Stat('Featured',
                        _videos.where((v) => v.isFeatured).length.toString()),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Featured video rotates automatically every day at 6:00 UTC. '
                  'Add new videos anytime — they appear in "New in Library" for two weeks.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          // Filter chips
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: ['All', 'Published', 'Draft', 'Featured']
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ))
                  .toList(),
            ),
          ),
          // Video list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!),
                            TextButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _shown.isEmpty
                        ? Center(
                            child: Text('No videos',
                                style: GoogleFonts.nunito(color: Colors.grey)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _shown.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final v = _shown[i];
                              return _AdminVideoTile(
                                video: v,
                                onEdit: () => _showForm(v),
                                onDelete: () => _delete(v),
                                onTogglePublish: () => _togglePublish(v),
                                onToggleFeatured: () => _toggleFeatured(v),
                              ).animate(delay: (i * 20).ms).fade();
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
          Text(label,
              style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _AdminVideoTile extends StatelessWidget {
  final LibraryVideo video;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePublish;
  final VoidCallback onToggleFeatured;

  const _AdminVideoTile({
    required this.video,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePublish,
    required this.onToggleFeatured,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: video.thumbnailUrl,
                width: 100,
                height: 60,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 100, height: 60,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.play_circle_outline, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('${video.channelName}  ·  ${video.topic}',
                      style: GoogleFonts.nunito(
                          fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Chip(
                        label: video.isPublished ? 'Live' : 'Draft',
                        color: video.isPublished
                            ? Colors.green
                            : Colors.orange,
                        onTap: onTogglePublish,
                      ),
                      const SizedBox(width: 6),
                      if (video.isFeatured)
                        _Chip(
                          label: '★ Featured',
                          color: Colors.amber.shade700,
                          onTap: onToggleFeatured,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18),
              onSelected: (val) {
                if (val == 'edit') onEdit();
                if (val == 'publish') onTogglePublish();
                if (val == 'feature') onToggleFeatured();
                if (val == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                    value: 'publish',
                    child: Text(video.isPublished ? 'Unpublish' : 'Publish')),
                PopupMenuItem(
                    value: 'feature',
                    child: Text(video.isFeatured
                        ? 'Remove featured'
                        : 'Set as featured')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}

// ── Video Form Sheet ──────────────────────────────────────────────────────────

class _VideoForm extends StatefulWidget {
  final LibraryVideo? initial;
  final Future<void> Function(LibraryVideo) onSave;

  const _VideoForm({this.initial, required this.onSave});

  @override
  State<_VideoForm> createState() => _VideoFormState();
}

class _VideoFormState extends State<_VideoForm> {
  final _formKey = GlobalKey<FormState>();
  final _ytIdCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _channelCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  String _topic = kLibraryTopics[1];
  bool _published = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    if (v != null) {
      _ytIdCtrl.text = v.youtubeId;
      _titleCtrl.text = v.title;
      _descCtrl.text = v.description ?? '';
      _channelCtrl.text = v.channelName;
      _tagsCtrl.text = v.tags.join(', ');
      _durationCtrl.text = v.durationSeconds.toString();
      _topic = v.topic;
      _published = v.isPublished;
    }
  }

  @override
  void dispose() {
    for (final c in [_ytIdCtrl, _titleCtrl, _descCtrl, _channelCtrl, _tagsCtrl, _durationCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final video = LibraryVideo(
        id: widget.initial?.id ?? '',
        youtubeId: _ytIdCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        channelName: _channelCtrl.text.trim(),
        topic: _topic,
        tags: tags,
        durationSeconds: int.tryParse(_durationCtrl.text.trim()) ?? 0,
        isFeatured: widget.initial?.isFeatured ?? false,
        featuredDate: widget.initial?.featuredDate,
        isPublished: _published,
        viewCount: widget.initial?.viewCount ?? 0,
        sortOrder: widget.initial?.sortOrder ?? 0,
        createdAt: widget.initial?.createdAt ?? DateTime.now(),
      );
      await widget.onSave(video);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    widget.initial == null ? 'Add Video' : 'Edit Video',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (_saving)
                    const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    TextButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _field(_ytIdCtrl, 'YouTube ID *', hint: 'e.g. dQw4w9WgXcQ',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null),
                    _field(_titleCtrl, 'Title *',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null),
                    _field(_channelCtrl, 'Channel Name *',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null),
                    _field(_descCtrl, 'Description', maxLines: 3),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _topic,
                      decoration: const InputDecoration(
                          labelText: 'Topic',
                          border: OutlineInputBorder()),
                      items: kLibraryTopics
                          .skip(1)
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() => _topic = v!),
                    ),
                    const SizedBox(height: 12),
                    _field(_tagsCtrl, 'Tags (comma-separated)',
                        hint: 'e.g. science, physics, curiosity'),
                    _field(_durationCtrl, 'Duration (seconds)',
                        keyboardType: TextInputType.number,
                        hint: 'e.g. 487'),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _published,
                      onChanged: (v) => setState(() => _published = v),
                      title: const Text('Published (visible to users)'),
                      contentPadding: EdgeInsets.zero,
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

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}
