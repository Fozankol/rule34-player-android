import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/post_model.dart';
import '../models/download_item.dart';
import '../providers/favorites_provider.dart';
import '../providers/downloads_provider.dart';
import 'speed_selector_dialog.dart';

class ReelsPlayerItem extends StatefulWidget {
  final PostModel post;
  final bool isCurrent;
  final bool isPreload;
  final Function(String tag)? onTagSelected;

  const ReelsPlayerItem({
    super.key,
    required this.post,
    required this.isCurrent,
    this.isPreload = false,
    this.onTagSelected,
  });

  @override
  State<ReelsPlayerItem> createState() => _ReelsPlayerItemState();
}

class _ReelsPlayerItemState extends State<ReelsPlayerItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  double _playbackSpeed = 1.0;
  bool _isMuted = false;
  bool _showPlayPauseRipple = false;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    if (widget.isCurrent || widget.isPreload) {
      _initPlayer();
    }
  }

  void _disposeCurrentController() {
    _controller?.removeListener(_playerListener);
    _controller?.dispose();
    _controller = null;
  }

  @override
  void didUpdateWidget(covariant ReelsPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.id != oldWidget.post.id) {
      _disposeCurrentController();
      _isInitialized = false;
      _hasError = false;
      _errorMessage = '';
      if (widget.isCurrent || widget.isPreload) {
        _initPlayer();
      }
    } else if (widget.isCurrent && !oldWidget.isCurrent) {
      if (_controller == null) {
        _initPlayer();
      } else {
        _controller?.play();
        setState(() {
          _isPlaying = true;
        });
      }
    } else if (!widget.isCurrent && oldWidget.isCurrent) {
      _controller?.pause();
      setState(() {
        _isPlaying = false;
      });
    } else if (!widget.isCurrent && !widget.isPreload && (oldWidget.isCurrent || oldWidget.isPreload)) {
      // Discard controller when page scrolls out of preload range to preserve RAM/decoders
      _disposeCurrentController();
      setState(() {
        _isInitialized = false;
      });
    } else if (!widget.isCurrent && widget.isPreload && _controller == null) {
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    _disposeCurrentController();
    try {
      if (widget.post.localFilePath != null &&
          File(widget.post.localFilePath!).existsSync()) {
        _controller = VideoPlayerController.file(File(widget.post.localFilePath!));
      } else {
        final headers = <String, String>{
          'User-Agent': 'Rule34VideoPlayer/1.0',
        };
        if (widget.post.fileUrl.contains('realbooru.com')) {
          headers['Referer'] = 'https://realbooru.com/';
        }

        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.post.fileUrl),
          httpHeaders: headers,
        );
      }

      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setPlaybackSpeed(_playbackSpeed);
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);

      if (widget.isCurrent) {
        await _controller!.play();
      } else {
        await _controller!.pause();
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = _controller!.value.isPlaying;
        });
      }

      _controller!.addListener(_playerListener);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _playerListener() {
    if (!mounted || _controller == null) return;
    if (_isPlaying != _controller!.value.isPlaying) {
      setState(() {
        _isPlaying = _controller!.value.isPlaying;
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }

    setState(() {
      _showPlayPauseRipple = true;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showPlayPauseRipple = false;
        });
      }
    });
  }

  void _seekRelative(int seconds) {
    if (_controller == null || !_isInitialized) return;
    final current = _controller!.value.position;
    final target = current + Duration(seconds: seconds);
    _controller!.seekTo(target);
  }

  void _showTagListModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Теги (${widget.post.tags.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.post.tags.map((tag) {
                      return ActionChip(
                        backgroundColor: const Color(0xFF2C2C38),
                        label: Text(
                          tag,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onTagSelected?.call(tag);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _disposeCurrentController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favProvider = context.watch<FavoritesProvider>();
    final dlProvider = context.watch<DownloadsProvider>();
    final isFav = favProvider.isFavorite(widget.post.id);
    final isDl = dlProvider.isDownloaded(widget.post.id);
    final dlItem = dlProvider.getItem(widget.post.id);

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Layer
          if (_isInitialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Не удалось загрузить видео',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                      ),
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                        });
                        _initPlayer();
                      },
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            ),

          // Double tap seek zones & single tap play/pause
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: () => _seekRelative(-10),
                    onTap: _togglePlayPause,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: () => _seekRelative(10),
                    onTap: _togglePlayPause,
                  ),
                ),
              ],
            ),
          ),

          // Play/Pause center animated ripple
          if (_showPlayPauseRipple)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.play_arrow : Icons.pause,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),

          // Right side action controls
          Positioned(
            right: 12,
            bottom: 90,
            child: Column(
              children: [
                // Favorite Button
                _buildActionButton(
                  icon: isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.redAccent : Colors.white,
                  label: '${widget.post.score}',
                  onTap: () => favProvider.toggleFavorite(widget.post),
                ),
                const SizedBox(height: 16),

                // Download Button
                if (isDl)
                  _buildActionButton(
                    icon: Icons.download_done,
                    color: Colors.greenAccent,
                    label: 'Сохранено',
                    onTap: () {},
                  )
                else if (dlItem?.status == DownloadStatus.downloading)
                  Column(
                    children: [
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(
                          value: dlItem?.progress,
                          color: Colors.greenAccent,
                          backgroundColor: Colors.white24,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${((dlItem?.progress ?? 0) * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  )
                else
                  _buildActionButton(
                    icon: Icons.download_rounded,
                    color: Colors.white,
                    label: 'Скачать',
                    onTap: () => dlProvider.startDownload(widget.post),
                  ),
                const SizedBox(height: 16),

                // Speed Selector
                _buildActionButton(
                  icon: Icons.speed,
                  color: Colors.white,
                  label: '${_playbackSpeed}x',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => SpeedSelectorDialog(
                        currentSpeed: _playbackSpeed,
                        onSpeedSelected: (newSpeed) {
                          setState(() {
                            _playbackSpeed = newSpeed;
                            _controller?.setPlaybackSpeed(newSpeed);
                          });
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Mute / Unmute
                _buildActionButton(
                  icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  label: _isMuted ? 'Выкл' : 'Звук',
                  onTap: () {
                    setState(() {
                      _isMuted = !_isMuted;
                      _controller?.setVolume(_isMuted ? 0.0 : 1.0);
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Tags modal
                _buildActionButton(
                  icon: Icons.label_outline,
                  color: Colors.white,
                  label: 'Теги',
                  onTap: _showTagListModal,
                ),
              ],
            ),
          ),

          // Bottom info and seekbar overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post ID & Duration badge
                  Row(
                    children: [
                      Text(
                        'Post #${widget.post.id}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.post.formattedDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Tags horizontal preview
                  if (widget.post.tags.isNotEmpty)
                    SizedBox(
                      height: 26,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.post.tags.take(6).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, idx) {
                          final tag = widget.post.tags[idx];
                          return GestureDetector(
                            onTap: () => widget.onTagSelected?.call(tag),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '#$tag',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Video Scrubber / Progress Bar
                  if (_isInitialized && _controller != null)
                    VideoProgressIndicator(
                      _controller!,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFF00C853),
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white10,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
