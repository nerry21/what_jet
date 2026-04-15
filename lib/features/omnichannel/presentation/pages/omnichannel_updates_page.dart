import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import '../../data/models/omnichannel_status_update_model.dart';
import '../../data/repositories/omnichannel_repository.dart';

class OmnichannelUpdatesPage extends StatefulWidget {
  const OmnichannelUpdatesPage({super.key, required this.repository});

  final OmnichannelRepository repository;

  @override
  State<OmnichannelUpdatesPage> createState() => _OmnichannelUpdatesPageState();
}

class _OmnichannelUpdatesPageState extends State<OmnichannelUpdatesPage> {
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isRecording = false;
  String? _errorMessage;
  List<OmnichannelStatusUpdateModel> _statuses =
      const <OmnichannelStatusUpdateModel>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadStatuses());
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _loadStatuses({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final items = await widget.repository.loadStatusUpdates();
      if (!mounted) {
        return;
      }

      setState(() {
        _statuses = items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '$error';
      });
    }
  }

  Future<void> _createTextStatus() async {
    final textController = TextEditingController();
    var backgroundColor = '#7EC8A5';
    final textColor = '#FFFFFF';

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Status Teks',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    maxLines: 5,
                    minLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Ketik status',
                      filled: true,
                      fillColor: AppColors.surfaceSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Warna latar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children:
                        <String>[
                              '#7EC8A5',
                              '#25D366',
                              '#496A5D',
                              '#6D4C41',
                              '#5C6BC0',
                            ]
                            .map((color) {
                              return GestureDetector(
                                onTap: () => setLocalState(
                                  () => backgroundColor = color,
                                ),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: _hexToColor(color),
                                  child: backgroundColor == color
                                      ? const Icon(
                                          Icons.check,
                                          color: AppColors.surfacePrimary,
                                          size: 18,
                                        )
                                      : null,
                                ),
                              );
                            })
                            .toList(growable: false),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Publikasikan'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (submitted != true) {
      textController.dispose();
      return;
    }

    await _submitStatus(
      () => widget.repository.createStatusUpdate(
        statusType: 'text',
        text: textController.text,
        backgroundColor: backgroundColor,
        textColor: textColor,
        fontStyle: 'default',
      ),
      successMessage: 'Status teks berhasil dibuat.',
    );

    textController.dispose();
  }

  Future<void> _createMusicStatus() async {
    final titleController = TextEditingController();
    final artistController = TextEditingController();
    final captionController = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tempel Musik',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: _inputDecoration('Judul lagu'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: artistController,
                decoration: _inputDecoration('Nama artis'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: captionController,
                decoration: _inputDecoration('Caption tambahan'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Publikasikan'),
              ),
            ],
          ),
        );
      },
    );

    if (submitted != true) {
      titleController.dispose();
      artistController.dispose();
      captionController.dispose();
      return;
    }

    await _submitStatus(
      () => widget.repository.createStatusUpdate(
        statusType: 'music',
        text: captionController.text,
        caption: captionController.text,
        musicTitle: titleController.text,
        musicArtist: artistController.text,
        backgroundColor: '#F6F6F6',
        textColor: '#111111',
      ),
      successMessage: 'Status musik berhasil dibuat.',
    );

    titleController.dispose();
    artistController.dispose();
    captionController.dispose();
  }

  Future<void> _createImageStatus({required ImageSource source}) async {
    final file = await _imagePicker.pickImage(source: source, imageQuality: 88);
    if (file == null) {
      return;
    }

    final bytes = await file.readAsBytes();

    await _submitStatus(
      () => widget.repository.createStatusUpdate(
        statusType: 'image',
        fileBytes: bytes,
        fileName: file.name,
        mimeType: _mimeTypeFromName(file.name, fallback: 'image/jpeg'),
      ),
      successMessage: 'Status foto berhasil dibuat.',
    );
  }

  Future<void> _createVideoStatus() async {
    final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (file == null) {
      return;
    }

    final bytes = await file.readAsBytes();

    await _submitStatus(
      () => widget.repository.createStatusUpdate(
        statusType: 'video',
        fileBytes: bytes,
        fileName: file.name,
        mimeType: _mimeTypeFromName(file.name, fallback: 'video/mp4'),
      ),
      successMessage: 'Status video berhasil dibuat.',
    );
  }

  Future<void> _toggleVoiceStatus() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      if (path == null || path.trim().isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() => _isRecording = false);
        _showSnackBar('File suara tidak ditemukan.');
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() => _isRecording = false);

      final file = File(path);
      final bytes = await file.readAsBytes();

      await _submitStatus(
        () => widget.repository.createStatusUpdate(
          statusType: 'audio',
          fileBytes: bytes,
          fileName: path.split(Platform.pathSeparator).last,
          mimeType: 'audio/mp4',
        ),
        successMessage: 'Status suara berhasil dibuat.',
      );
      return;
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      _showSnackBar('Izin mikrofon belum diberikan.');
      return;
    }

    final tempPath =
        '${Directory.systemTemp.path}/status_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: tempPath,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isRecording = true);
    _showSnackBar('Perekaman suara dimulai. Tekan lagi untuk kirim.');
  }

  Future<void> _submitStatus(
    Future<OmnichannelStatusUpdateModel> Function() action, {
    required String successMessage,
  }) async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final item = await action();
      if (!mounted) {
        return;
      }

      setState(() {
        _statuses = <OmnichannelStatusUpdateModel>[item, ..._statuses];
      });

      _showSnackBar(successMessage);
    } catch (error) {
      _showSnackBar('Gagal membuat status: $error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _statuses.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                size: 42,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadStatuses,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadStatuses(silent: true),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: <Widget>[
          const Text(
            'Pembaharuan',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          _buildComposerActions(),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Status saya',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              if (_isSubmitting)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_statuses.isEmpty)
            Container(
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceTertiary,
                borderRadius: AppRadii.borderRadiusXl,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Text(
                'Belum ada status. Buat status teks, foto, video, suara, atau musik dari tombol di atas.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            )
          else
            ..._statuses.map(_buildStatusCard),
        ],
      ),
    );
  }

  Widget _buildComposerActions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _ComposerActionCard(
          icon: Icons.edit_rounded,
          label: 'Teks',
          onTap: _createTextStatus,
        ),
        _ComposerActionCard(
          icon: Icons.music_note_rounded,
          label: 'Musik',
          onTap: _createMusicStatus,
        ),
        _ComposerActionCard(
          icon: Icons.photo_library_outlined,
          label: 'Foto',
          onTap: () => _createImageStatus(source: ImageSource.gallery),
        ),
        _ComposerActionCard(
          icon: Icons.videocam_outlined,
          label: 'Video',
          onTap: _createVideoStatus,
        ),
        _ComposerActionCard(
          icon: _isRecording
              ? Icons.stop_circle_outlined
              : Icons.mic_none_rounded,
          label: _isRecording ? 'Kirim Suara' : 'Suara',
          onTap: _toggleVoiceStatus,
        ),
        _ComposerActionCard(
          icon: Icons.camera_alt_outlined,
          label: 'Kamera',
          onTap: () => _createImageStatus(source: ImageSource.camera),
        ),
      ],
    );
  }

  Widget _buildStatusCard(OmnichannelStatusUpdateModel item) {
    final bgColor = _hexToColor(item.backgroundColor ?? '#F6F6F6');
    final fgColor = _hexToColor(item.textColor ?? '#111111');

    return Container(
      margin: EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadii.borderRadiusXxl,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (item.isText || item.isMusic)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if ((item.musicTitle ?? '').isNotEmpty) ...<Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.music_note_rounded, color: fgColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.musicTitle!,
                            style: TextStyle(
                              color: fgColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((item.musicArtist ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        item.musicArtist!,
                        style: TextStyle(
                          color: fgColor.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                  if ((item.text ?? '').isNotEmpty)
                    Text(
                      item.text!,
                      style: TextStyle(
                        color: fgColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                ],
              ),
            ),
          if (item.isImage && (item.mediaUrl ?? '').isNotEmpty)
            ClipRRect(
              borderRadius: AppRadii.borderRadiusXxl,
              child: Image.network(
                item.mediaUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 240,
                errorBuilder: (_, __, ___) => _buildMediaPlaceholder(
                  icon: Icons.broken_image_outlined,
                  label: 'Gambar tidak dapat dimuat',
                ),
              ),
            ),
          if (item.isVideo)
            _buildMediaPlaceholder(
              icon: Icons.play_circle_outline_rounded,
              label: item.mediaOriginalName ?? 'Video status',
            ),
          if (item.isAudio)
            _buildMediaPlaceholder(
              icon: Icons.graphic_eq_rounded,
              label: item.mediaOriginalName ?? 'Status suara',
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _formatDate(item.postedAt),
                    style: TextStyle(
                      color: AppColors.neutral500,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.neutral500,
                ),
                const SizedBox(width: 6),
                Text(
                  '${item.viewCount}',
                  style: TextStyle(
                    color: AppColors.neutral500,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPlaceholder({
    required IconData icon,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      height: 190,
      decoration: BoxDecoration(
        color: AppColors.surfaceTertiary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 44, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surfaceSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}.${local.minute.toString().padLeft(2, '0')}';
  }

  static Color _hexToColor(String hex) {
    final value = hex.replaceAll('#', '').trim();
    if (value.length == 6) {
      return Color(int.parse('FF$value', radix: 16));
    }
    if (value.length == 8) {
      return Color(int.parse(value, radix: 16));
    }
    return const Color(0xFF7EC8A5);
  }

  static String _mimeTypeFromName(String fileName, {required String fallback}) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.mp4')) {
      return 'video/mp4';
    }
    if (lower.endsWith('.mov')) {
      return 'video/quicktime';
    }
    return fallback;
  }
}

class _ComposerActionCard extends StatelessWidget {
  const _ComposerActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 106,
      child: Material(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadii.borderRadiusXl,
        child: InkWell(
          borderRadius: AppRadii.borderRadiusXl,
          onTap: onTap,
          child: Ink(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: AppRadii.borderRadiusXl,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: <Widget>[
                Icon(icon, size: 30, color: AppColors.primary),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
