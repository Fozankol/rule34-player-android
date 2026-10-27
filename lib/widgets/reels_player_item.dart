import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/post_model.dart';
import '../models/download_item.dart';
import '../providers/favorites_provider.dart';
import '../providers/downloads_provider.dart';
import '../theme/app_theme.dart';
import '../services/playback_session.dart';
import '../services/realbooru_service.dart';
import '../l10n/app_strings.dart';
import 'speed_selector_dialog.dart';

class ReelsPlayerItem extends StatefulWidget {
  final PostModel post;
  final bool isCurrent;
  final bool isPreload;
  final Function(String tag)? onTagSelected;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String? pageLabel;

  const ReelsPlayerItem({super.key, required this.post, required this.isCurrent,
    this.isPreload = false, this.onTagSelected, this.onBack, this.onNext, this.pageLabel});

  @override
  State<ReelsPlayerItem> createState() => _ReelsPlayerItemState();
}

class _ReelsPlayerItemState extends State<ReelsPlayerItem> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _error;
  double _speed = 1;
  bool _muted = false;
  bool _resumeAfterBackground = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  int _generation = 0;
  bool _codecRecoveryUsed = false;
  bool _wasPlaying = false;
  Duration _lastPosition = Duration.zero;
  int _openDialogs = 0;

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!widget.isCurrent || _error != null || !_isInitialized ||
        !(_controller?.value.isPlaying ?? false) || _openDialogs > 0) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    _scheduleHide();
  }

  bool _isCodecError(String message) => RegExp('codec|decoder|VideoRenderer', caseSensitive: false).hasMatch(message);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isCurrent) _initPlayer();
  }

  void _release() {
    _generation++;
    _hideTimer?.cancel();
    final controller = _controller;
    _controller = null;
    _isInitialized = false;
    controller?.removeListener(_listen);
    if (controller != null) {
      PlaybackSession.instance.release(controller).catchError((Object _) {});
    }
  }

  @override
  void didUpdateWidget(covariant ReelsPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.fileUrl != oldWidget.post.fileUrl) {
      _codecRecoveryUsed = false;
      _lastPosition = Duration.zero;
      _release();
    }
    if (!widget.isCurrent) {
      _release();
    } else if (!oldWidget.isCurrent || widget.post.fileUrl != oldWidget.post.fileUrl) {
      _codecRecoveryUsed = false;
      _controlsVisible = true;
      _initPlayer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_resumeAfterBackground && widget.isCurrent) _controller?.play();
      _resumeAfterBackground = false;
    } else {
      _resumeAfterBackground = _resumeAfterBackground || (_controller?.value.isPlaying ?? false);
      _controller?.pause();
    }
  }

  Future<void> _initPlayer({bool recovering = false}) async {
    _release();
    final generation = _generation;
    _error = null;
    _controlsVisible = true;
    VideoPlayerController? controller;
    try {
      final local = widget.post.localFilePath;
      final headers = getMediaHeaders(widget.post.fileUrl, userAgent: 'Rule34VideoPlayer/1.0');
      controller = await PlaybackSession.instance.open(() => local != null && File(local).existsSync()
          ? VideoPlayerController.file(File(local))
          : VideoPlayerController.networkUrl(Uri.parse(widget.post.fileUrl), httpHeaders: headers),
          isCurrent: () => mounted && widget.isCurrent && generation == _generation);
      if (controller == null || !mounted || generation != _generation) return;
      _controller = controller;
      if (!mounted || _controller != controller) return;
      await controller.setLooping(true);
      if (!mounted || _controller != controller) return;
      await controller.setPlaybackSpeed(_speed);
      if (!mounted || _controller != controller) return;
      await controller.setVolume(_muted ? 0 : 1);
      if (!mounted || _controller != controller) return;
      if (recovering && _lastPosition > Duration.zero) {
        await controller.seekTo(_lastPosition);
        if (!mounted || _controller != controller) return;
      }
      if (widget.isCurrent && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await controller.play();
      }
      if (!mounted || _controller != controller) return;
      controller.addListener(_listen);
      setState(() => _isInitialized = true);
      _wasPlaying = controller.value.isPlaying;
      _scheduleHide();

      if (widget.post.fileUrl.contains('realbooru.com')) {
        RealbooruService().getDetails(widget.post).then((detailed) {
          if (mounted && generation == _generation) {
            widget.post.score = detailed.score;
            widget.post.hasExactScore = true;
            if (detailed.tags.isNotEmpty) {
              widget.post.tags = detailed.tags;
            }
            if (mounted) setState(() {});
          }
        }).catchError((_) {});
      }
    } catch (e) {
      if (mounted && generation == _generation && widget.isCurrent) {
        _handleError(e.toString());
      }
    }
  }

  void _listen() {
    if (!mounted) return;
    final value = _controller?.value;
    if (value?.hasError ?? false) {
      final description = value!.errorDescription ?? 'Ошибка воспроизведения';
      _handleError(description);
    } else if (value != null) {
      _lastPosition = value.position;
      if (_wasPlaying != value.isPlaying) {
        _wasPlaying = value.isPlaying;
        if (!value.isPlaying) setState(() => _controlsVisible = true);
        _scheduleHide();
      }
    }
  }

  void _handleError(String error) {
    _release();
    if (_isCodecError(error) && !_codecRecoveryUsed && widget.isCurrent) {
      _codecRecoveryUsed = true;
      setState(() => _error = null);
      _initPlayer(recovering: true);
    } else {
      setState(() { _error = error; _controlsVisible = true; });
    }
  }

  void _toggle() {
    final controller = _controller;
    if (!_isInitialized || controller == null) return;
    controller.value.isPlaying ? controller.pause() : controller.play();
  }

  void _seek(int seconds) {
    _scheduleHide();
    final controller = _controller;
    if (!_isInitialized || controller == null) return;
    final target = (controller.value.position.inMilliseconds + seconds * 1000)
        .clamp(0, controller.value.duration.inMilliseconds);
    controller.seekTo(Duration(milliseconds: target));
  }

  String _time(Duration value) {
    final seconds = value.inSeconds;
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _tags() async {
    _hideTimer?.cancel();
    _openDialogs++;
    await showModalBottomSheet<void>(
      context: context, backgroundColor: AppTheme.surface, isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .55,
          child: Column(children: [
            ListTile(title: Text('${AppStrings.of(context).tags} · ${widget.post.tags.length}'),
              trailing: IconButton(tooltip: AppStrings.of(context).close, icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(sheetContext))),
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Wrap(spacing: 8, runSpacing: 8, children: widget.post.tags.map((tag) => ActionChip(
                label: Text(tag), onPressed: () {
                  Navigator.pop(sheetContext);
                  widget.onTagSelected?.call(tag);
                },
              )).toList()))),
          ]),
        ),
      ),
    );
    _openDialogs--;
    if (mounted) _scheduleHide();
  }

  void _showDetails() {
    final tr = AppStrings.of(context);
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr.errorDetails),
      content: SingleChildScrollView(child: SelectableText(_error ?? '')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr.close))],
    ));
  }

  Widget _errorView() {
    final tr = AppStrings.of(context);
    final codec = _isCodecError(_error ?? '');
    return Center(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(28, 88, 28, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(codec ? Icons.video_settings_rounded : Icons.wifi_off_rounded, size: 44, color: AppTheme.error),
        const SizedBox(height: 18),
        Text(codec ? tr.failedToPlay : tr.failedToLoad, textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.text, fontSize: 23, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(codec ? tr.codecErrorText : tr.networkErrorText,
          textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted, height: 1.5, fontSize: 14)),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: () { setState(() => _error = null); _codecRecoveryUsed = false; _initPlayer(); },
          icon: const Icon(Icons.refresh_rounded), label: Text(tr.retryLoading)),
        const SizedBox(height: 4),
        TextButton(onPressed: _showDetails, child: Text(tr.errorDetails)),
        Wrap(alignment: WrapAlignment.center, spacing: 12, children: [
          TextButton.icon(icon: const Icon(Icons.download_outlined), label: Text(tr.download),
            onPressed: () => context.read<DownloadsProvider>().startDownload(widget.post)),
          TextButton.icon(icon: const Icon(Icons.sell_outlined), label: Text(tr.tags), onPressed: _tags),
        ]),
      ]),
    ));
  }

  Widget _action(IconData icon, String label, VoidCallback onTap, {Color color = AppTheme.text}) {
    return Expanded(child: Tooltip(message: label, child: InkWell(
      onTap: () { _scheduleHide(); onTap(); }, borderRadius: BorderRadius.circular(12),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 24), const SizedBox(height: 6),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.3)),
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ])),
    )));
  }

  Widget _transport(VideoPlayerController controller) => ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: controller,
    builder: (context, value, _) => Column(children: [
      Row(children: [
        IconButton(tooltip: value.isPlaying ? 'Пауза' : 'Воспроизвести', onPressed: _toggle,
          icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)),
        Text(_time(value.position), style: const TextStyle(fontSize: 12, color: AppTheme.text)),
        const Spacer(),
        if (value.isBuffering) const Padding(padding: EdgeInsets.only(right: 12),
          child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
        Text(_time(value.duration), style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
      ]),
      VideoProgressIndicator(controller, allowScrubbing: true,
        padding: const EdgeInsets.symmetric(vertical: 12),
        colors: const VideoProgressColors(playedColor: AppTheme.accent,
          bufferedColor: AppTheme.muted, backgroundColor: AppTheme.raised)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final tr = AppStrings.of(context);
    final favorites = context.watch<FavoritesProvider>();
    final downloads = context.watch<DownloadsProvider>();
    final favorite = favorites.isFavorite(widget.post.id);
    final saved = downloads.isDownloaded(widget.post.id);
    final item = downloads.getItem(widget.post.id);
    final downloading = item?.status == DownloadStatus.downloading;
    final controller = _controller;

    return ColoredBox(color: Colors.black, child: Stack(fit: StackFit.expand, children: [
        if (_error != null) _errorView()
        else if (_isInitialized && controller != null) ...[
          Center(child: AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller))),
          Row(children: [
            Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent,
              key: const ValueKey('video-left-gesture'),
              onTap: _toggleControls, onDoubleTap: () => _seek(-10))),
            Expanded(child: GestureDetector(behavior: HitTestBehavior.translucent,
              onTap: _toggleControls, onDoubleTap: () => _seek(10))),
          ]),
        ] else Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(height: 16), Text(tr.loadingVideo, style: const TextStyle(color: AppTheme.muted)),
        ])),
      if (_controlsVisible) Positioned(
        top: MediaQuery.of(context).padding.top + 8, left: 12, right: 12,
        child: Row(children: [
          IconButton(tooltip: tr.back, style: IconButton.styleFrom(backgroundColor: Colors.black54),
            icon: const Icon(Icons.arrow_back_rounded), onPressed: widget.onBack ?? () => Navigator.maybePop(context)),
          const Spacer(),
          if (widget.pageLabel != null) Text(widget.pageLabel!, style: const TextStyle(color: Colors.white)),
          const Spacer(),
          if (_error == null && _isInitialized) IconButton(tooltip: tr.hideControls, style: IconButton.styleFrom(backgroundColor: Colors.black54),
            icon: const Icon(Icons.visibility_off_outlined), onPressed: () {
              setState(() => _controlsVisible = false); _hideTimer?.cancel();
            }),
          if (widget.onNext != null) IconButton(tooltip: tr.nextVideo,
            icon: const Icon(Icons.skip_next_rounded), onPressed: widget.onNext),
        ]),
      ),
      if (_controlsVisible && _error == null && _isInitialized) Positioned(left: 0, right: 0, bottom: 0,
       child: Listener(onPointerDown: (_) => _hideTimer?.cancel(), onPointerUp: (_) => _scheduleHide(),
        child: ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .42),
       child: SingleChildScrollView(child: ColoredBox(color: AppTheme.background, child: SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.movie_outlined, size: 18, color: AppTheme.muted),
            const SizedBox(width: 8),
            Expanded(child: Text('Video #${widget.post.id}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            Text(widget.post.formattedDuration, style: const TextStyle(color: AppTheme.accent, fontSize: 13)),
          ]),
          if (_isInitialized && controller != null) _transport(controller) else const SizedBox(height: 8),
          Row(children: [
            _action(favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              '${widget.post.score}', () => favorites.toggleFavorite(widget.post),
              color: favorite ? AppTheme.error : AppTheme.text),
            _action(saved ? Icons.download_done_rounded : downloading ? Icons.downloading_rounded : Icons.download_rounded,
              saved ? tr.saved : downloading ? '${((item?.progress ?? 0) * 100).toInt()}%' : tr.download,
              () { if (!saved && !downloading) downloads.startDownload(widget.post); }),
            _action(Icons.speed_rounded, '${_speed}×', () => showDialog<void>(context: context,
              builder: (_) => SpeedSelectorDialog(currentSpeed: _speed, onSpeedSelected: (speed) {
                setState(() => _speed = speed); _controller?.setPlaybackSpeed(speed);
              }))),
            _action(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, _muted ? tr.muted : tr.sound, () {
              setState(() => _muted = !_muted); _controller?.setVolume(_muted ? 0 : 1);
            }),
            _action(Icons.sell_outlined, tr.tags, _tags),
          ]),
        ]),
      ))))))),
    ]));
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }
}
