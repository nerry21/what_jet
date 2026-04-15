import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

import '../../data/models/customer_status_group.dart';
import '../../data/models/customer_status_item.dart';
import '../../data/repositories/customer_status_repository.dart';
import '../../data/services/status_analytics_service.dart';
import '../widgets/video_buffer_indicator.dart';

class CustomerStatusViewerPage extends StatefulWidget {
  const CustomerStatusViewerPage({
    super.key,
    required this.group,
    required this.repository,
  });

  final CustomerStatusGroup group;
  final CustomerStatusRepository repository;

  @override
  State<CustomerStatusViewerPage> createState() =>
      _CustomerStatusViewerPageState();
}

class _CustomerStatusViewerPageState extends State<CustomerStatusViewerPage>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _progressController;

  final StatusAnalyticsService _analytics = const StatusAnalyticsService();

  VideoPlayerController? _videoController;
  VideoPlayerController? _nextVideoController;
  AudioPlayer? _audioPlayer;

  int _index = 0;
  int? _nextVideoStatusId;
  bool _isPaused = false;
  bool _isHolding = false;
  bool _isMediaLoading = false;
  bool _isVideoMuted = true;
  bool _isVideoBuffering = false;
  bool _hasMediaError = false;
  double _verticalDragOffset = 0;

  List<CustomerStatusItem> get _statuses => widget.group.statuses;
  CustomerStatusItem get _currentItem => _statuses[_index];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _progressController =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              unawaited(_goNext(source: 'auto_progress'));
            }
          });

    unawaited(_trackOpen());
    unawaited(_initializeCurrentSlide());
  }

  @override
  void dispose() {
    unawaited(_trackClose());
    _progressController.dispose();
    unawaited(_videoController?.dispose());
    unawaited(_nextVideoController?.dispose());
    unawaited(_audioPlayer?.dispose());
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _trackOpen() {
    return _analytics.track(
      event: 'status_open',
      params: <String, Object?>{
        'author_id': widget.group.authorId,
        'author_name': widget.group.authorName,
        'status_id': _currentItem.id,
        'status_type': _currentItem.statusType,
        'index': _index,
        'total': _statuses.length,
      },
    );
  }

  Future<void> _trackClose() {
    return _analytics.track(
      event: 'status_close',
      params: <String, Object?>{
        'author_id': widget.group.authorId,
        'author_name': widget.group.authorName,
        'status_id': _currentItem.id,
        'status_type': _currentItem.statusType,
        'index': _index,
        'total': _statuses.length,
      },
    );
  }

  Future<void> _trackAction(
    String event, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    return _analytics.track(
      event: event,
      params: <String, Object?>{
        'author_id': widget.group.authorId,
        'author_name': widget.group.authorName,
        'status_id': _currentItem.id,
        'status_type': _currentItem.statusType,
        'index': _index,
        'total': _statuses.length,
        ...extra,
      },
    );
  }

  Future<void> _initializeCurrentSlide() async {
    _progressController.stop();
    _progressController.reset();

    await _disposeActiveMedia();

    if (!mounted) {
      return;
    }

    setState(() {
      _isMediaLoading = true;
      _isVideoBuffering = false;
      _hasMediaError = false;
    });

    await _markViewed();

    final item = _currentItem;

    try {
      if (item.isVideo && (item.mediaUrl ?? '').isNotEmpty) {
        await _setupVideo(item);
      } else if (item.isAudio && (item.mediaUrl ?? '').isNotEmpty) {
        await _setupAudio(item);
      } else {
        final seconds = _resolveStoryDuration(item);
        _progressController.duration = Duration(seconds: seconds);
        if (!_isPaused) {
          _progressController.forward();
        }
      }

      await _preloadNextSlide();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasMediaError = true;
      });
    }

    if (!mounted) {
      return;
    }

    setState(() => _isMediaLoading = false);
  }

  Future<void> _preloadNextSlide() async {
    await _nextVideoController?.dispose();
    _nextVideoController = null;
    _nextVideoStatusId = null;

    final nextIndex = _index + 1;
    if (nextIndex >= _statuses.length) {
      return;
    }

    final nextItem = _statuses[nextIndex];

    if (nextItem.isVideo && (nextItem.mediaUrl ?? '').isNotEmpty) {
      try {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(nextItem.mediaUrl!),
        );
        await controller.initialize();
        await controller.setVolume(0);
        _nextVideoController = controller;
        _nextVideoStatusId = nextItem.id;
      } catch (_) {}
    }
  }

  Future<void> _setupVideo(CustomerStatusItem item) async {
    _isVideoBuffering = true;

    if (_nextVideoController != null && _nextVideoStatusId == item.id) {
      _videoController = _nextVideoController;
      _nextVideoController = null;
      _nextVideoStatusId = null;
    } else {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(item.mediaUrl!),
      );
      await _videoController!.initialize();
    }

    await _videoController!.setLooping(false);
    await _videoController!.setVolume(_isVideoMuted ? 0 : 1);
    await _videoController!.play();

    final duration = _videoController!.value.duration;
    _progressController.duration = duration.inMilliseconds > 0
        ? duration
        : Duration(seconds: _resolveStoryDuration(item));

    _videoController!.addListener(_videoListener);

    _isVideoBuffering = false;

    if (!_isPaused) {
      _progressController.forward();
    }
  }

  Future<void> _setupAudio(CustomerStatusItem item) async {
    _audioPlayer = AudioPlayer();
    await _audioPlayer!.setUrl(item.mediaUrl!);
    await _audioPlayer!.play();

    final duration =
        _audioPlayer!.duration ??
        Duration(seconds: item.durationSeconds ?? _resolveStoryDuration(item));

    _progressController.duration = duration;

    _audioPlayer!.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }

      if (state.processingState == ProcessingState.completed) {
        unawaited(_goNext(source: 'audio_completed'));
      }
    });

    if (!_isPaused) {
      _progressController.forward();
    }
  }

  void _videoListener() {
    final controller = _videoController;
    if (controller == null || !mounted) {
      return;
    }

    final value = controller.value;

    final buffering = value.isBuffering;
    if (buffering != _isVideoBuffering) {
      setState(() {
        _isVideoBuffering = buffering;
      });
    }

    if (value.hasError && !_hasMediaError) {
      setState(() {
        _hasMediaError = true;
      });
      return;
    }

    if (value.isInitialized &&
        value.position >= value.duration &&
        !value.isPlaying) {
      unawaited(_goNext(source: 'video_completed'));
    }
  }

  Future<void> _disposeActiveMedia() async {
    if (_videoController != null) {
      _videoController!.removeListener(_videoListener);
      await _videoController!.pause();
      await _videoController!.dispose();
      _videoController = null;
    }

    if (_audioPlayer != null) {
      await _audioPlayer!.stop();
      await _audioPlayer!.dispose();
      _audioPlayer = null;
    }
  }

  int _resolveStoryDuration(CustomerStatusItem item) {
    if (item.isText || item.isMusic || item.isImage) {
      return 5;
    }
    if (item.isAudio || item.isVideo) {
      return item.durationSeconds ?? 8;
    }
    return 5;
  }

  Future<void> _markViewed() async {
    try {
      await widget.repository.markViewed(_currentItem.id);
    } catch (_) {}
  }

  Future<void> _retryCurrentMedia() async {
    await _trackAction('status_retry_media');
    if (!mounted) {
      return;
    }
    setState(() {
      _hasMediaError = false;
      _isMediaLoading = true;
      _isVideoBuffering = false;
    });
    await _initializeCurrentSlide();
  }

  Future<void> _goNext({String source = 'tap_right'}) async {
    await _trackAction(
      'status_next',
      extra: <String, Object?>{'source': source},
    );

    if (_index >= _statuses.length - 1) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    setState(() => _index += 1);

    await _pageController.animateToPage(
      _index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );

    await _initializeCurrentSlide();
  }

  Future<void> _goPrevious({String source = 'tap_left'}) async {
    if (_index <= 0) {
      return;
    }

    await _trackAction(
      'status_prev',
      extra: <String, Object?>{'source': source},
    );

    setState(() => _index -= 1);

    await _pageController.animateToPage(
      _index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );

    await _initializeCurrentSlide();
  }

  void _pauseStory() {
    if (_isPaused) {
      return;
    }

    _isPaused = true;
    _progressController.stop();
    unawaited(_videoController?.pause());
    unawaited(_audioPlayer?.pause());
    unawaited(
      _trackAction('status_pause', extra: <String, Object?>{'source': 'hold'}),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _resumeStory() {
    if (!_isPaused || _isHolding) {
      return;
    }

    _isPaused = false;
    if (_currentItem.isVideo) {
      unawaited(_videoController?.play());
    } else if (_currentItem.isAudio) {
      unawaited(_audioPlayer?.play());
    }
    _progressController.forward();
    unawaited(
      _trackAction(
        'status_resume',
        extra: <String, Object?>{'source': 'hold_release'},
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    _isHolding = true;
    _pauseStory();
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    _isHolding = false;
    _resumeStory();
  }

  Future<void> _handleHorizontalDragEnd(DragEndDetails details) async {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -120) {
      await _goNext(source: 'swipe_left');
    } else if (velocity > 120) {
      await _goPrevious(source: 'swipe_right');
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _verticalDragOffset += details.delta.dy;
      _verticalDragOffset = _verticalDragOffset.clamp(0, 220);
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_verticalDragOffset > 110) {
      unawaited(
        _trackAction(
          'status_close_gesture',
          extra: <String, Object?>{'source': 'swipe_down'},
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _verticalDragOffset = 0;
    });
  }

  Future<void> _toggleMute() async {
    final controller = _videoController;
    if (controller == null) {
      return;
    }

    setState(() => _isVideoMuted = !_isVideoMuted);
    await controller.setVolume(_isVideoMuted ? 0 : 1);
    await _trackAction(
      'status_mute_toggle',
      extra: <String, Object?>{'muted': _isVideoMuted},
    );
  }

  @override
  Widget build(BuildContext context) {
    final dragProgress = (_verticalDragOffset / 220).clamp(0.0, 1.0);
    final scale = 1 - (dragProgress * 0.08);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) async {
          final width = MediaQuery.of(context).size.width;
          if (details.localPosition.dx < width / 2) {
            await _goPrevious(source: 'tap_left');
          } else {
            await _goNext(source: 'tap_right');
          }
        },
        onLongPressStart: _handleLongPressStart,
        onLongPressEnd: _handleLongPressEnd,
        onHorizontalDragEnd: _handleHorizontalDragEnd,
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        onVerticalDragEnd: _handleVerticalDragEnd,
        child: SafeArea(
          child: Transform.translate(
            offset: Offset(0, _verticalDragOffset),
            child: Transform.scale(
              scale: scale,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: math.max(0.55, 1 - dragProgress),
                      child: _buildHeroContent(),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: List.generate(_statuses.length, (i) {
                        if (i < _index) {
                          return _doneSegment();
                        }
                        if (i == _index) {
                          return _activeSegment();
                        }
                        return _idleSegment();
                      }),
                    ),
                  ),
                  Positioned(
                    top: 24,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: <Widget>[
                        Hero(
                          tag: widget.group.heroTag,
                          flightShuttleBuilder:
                              (
                                BuildContext flightContext,
                                Animation<double> animation,
                                HeroFlightDirection flightDirection,
                                BuildContext fromHeroContext,
                                BuildContext toHeroContext,
                              ) {
                                return Material(
                                  color: Colors.transparent,
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.92,
                                      end: 1.0,
                                    ).animate(animation),
                                    child: toHeroContext.widget,
                                  ),
                                );
                              },
                          child: const Material(
                            color: Colors.transparent,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.group.authorName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTime(_currentItem.postedAt),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_currentItem.isVideo)
                          IconButton(
                            onPressed: _toggleMute,
                            icon: Icon(
                              _isVideoMuted
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                              color: Colors.white,
                            ),
                          ),
                        IconButton(
                          onPressed: () {
                            unawaited(_trackAction('status_close_button'));
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  if (_currentItem.isAudio)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 40,
                      child: _buildAudioOverlay(),
                    ),
                  if (dragProgress > 0)
                    Positioned(
                      bottom: 22,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Geser ke bawah untuk menutup',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSlide(CustomerStatusItem item) {
    if (item.isText || item.isMusic) {
      final backgroundColor = _hexToColor(item.backgroundColor ?? '#7EC8A5');
      final textColor = _hexToColor(item.textColor ?? '#FFFFFF');

      return Container(
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 120),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if ((item.musicTitle ?? '').isNotEmpty) ...<Widget>[
                const Icon(Icons.music_note, color: Colors.white, size: 42),
                const SizedBox(height: 12),
                Text(
                  item.musicTitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((item.musicArtist ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    item.musicArtist!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
              if ((item.text ?? '').isNotEmpty)
                Text(
                  item.text!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (item.isImage && (item.mediaUrl ?? '').isNotEmpty) {
      return SizedBox.expand(
        child: Image.network(
          item.mediaUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }
            return const _ViewerShimmerOverlay();
          },
          errorBuilder: (_, __, ___) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 44,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Gambar gagal dimuat',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _retryCurrentMedia,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    if (item.isVideo) {
      final controller = _videoController;
      if (controller != null && controller.value.isInitialized) {
        return Center(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        );
      }

      return const _ViewerShimmerOverlay();
    }

    if (item.isAudio) {
      return Container(
        color: const Color(0xFF121212),
        child: const Center(
          child: Icon(Icons.graphic_eq, size: 100, color: Colors.white),
        ),
      );
    }

    return const Center(
      child: Text(
        'Status tidak didukung',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildAudioOverlay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(20),
      ),
      child: StreamBuilder<PlayerState>(
        stream: _audioPlayer?.playerStateStream,
        builder: (context, snapshot) {
          final isPlaying = _audioPlayer?.playing ?? false;

          return Row(
            children: <Widget>[
              IconButton(
                onPressed: () async {
                  if (_audioPlayer == null) {
                    return;
                  }
                  if (isPlaying) {
                    await _audioPlayer!.pause();
                    _pauseStory();
                  } else {
                    await _audioPlayer!.play();
                    _isPaused = false;
                    _progressController.forward();
                    await _trackAction('status_audio_play');
                    if (mounted) {
                      setState(() {});
                    }
                  }
                },
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: _audioPlayer?.positionStream,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    final total = _audioPlayer?.duration ?? Duration.zero;
                    final progress = total.inMilliseconds <= 0
                        ? 0.0
                        : position.inMilliseconds / total.inMilliseconds;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        LinearProgressIndicator(
                          value: progress.clamp(0, 1),
                          minHeight: 4,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_formatDuration(position)} / ${_formatDuration(total)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _doneSegment() {
    return Expanded(
      child: Container(
        height: 3.5,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _idleSegment() {
    return Expanded(
      child: Container(
        height: 3.5,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _activeSegment() {
    return Expanded(
      child: Container(
        height: 3.5,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedBuilder(
          animation: _progressController,
          builder: (context, child) {
            return Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _progressController.value.clamp(0, 1),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static String _formatTime(DateTime? value) {
    if (value == null) {
      return '';
    }

    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}.${local.minute.toString().padLeft(2, '0')}';
  }

  static String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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

  Widget _buildHeroContent() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PageView.builder(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _statuses.length,
          itemBuilder: (context, index) {
            final item = _statuses[index];
            return _buildStatusSlide(item);
          },
        ),
        VideoBufferIndicator(
          isBuffering: _isVideoBuffering || _isMediaLoading,
          isError: _hasMediaError,
          onRetry: _retryCurrentMedia,
        ),
      ],
    );
  }
}

class _ViewerShimmerOverlay extends StatelessWidget {
  const _ViewerShimmerOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF222222),
        highlightColor: const Color(0xFF3A3A3A),
        child: const Center(
          child: Icon(Icons.image_outlined, size: 84, color: Colors.white),
        ),
      ),
    );
  }
}
