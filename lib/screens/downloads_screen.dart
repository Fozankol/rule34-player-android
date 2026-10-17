import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/download_item.dart';
import '../models/post_model.dart';
import '../providers/downloads_provider.dart';
import 'video_player_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dlProvider = context.watch<DownloadsProvider>();
    final downloads = dlProvider.downloads;

    return Scaffold(
      backgroundColor: const Color(0xFF141419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F28),
        title: Text(
          'Загрузки (${downloads.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: downloads.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.download_for_offline_outlined,
                      size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text(
                    'Нет загруженных видео',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Скачивайте видео для оффлайн-просмотра',
                    style: TextStyle(color: Colors.white30, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: downloads.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white12),
              itemBuilder: (context, index) {
                final item = downloads[index];
                return _buildDownloadTile(context, item, dlProvider);
              },
            ),
    );
  }

  Widget _buildDownloadTile(
    BuildContext context,
    DownloadItem item,
    DownloadsProvider dlProvider,
  ) {
    final isCompleted = item.status == DownloadStatus.completed;
    final isDownloading = item.status == DownloadStatus.downloading;

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF282834),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isCompleted
              ? Icons.play_arrow_rounded
              : isDownloading
                  ? Icons.downloading
                  : Icons.file_download_off,
          color: isCompleted ? Colors.greenAccent : Colors.white70,
          size: 28,
        ),
      ),
      title: Text(
        'Video #${item.postId}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            item.formattedProgress,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (isDownloading) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: item.progress > 0 ? item.progress : null,
              backgroundColor: Colors.white12,
              color: Colors.greenAccent,
            ),
          ],
          if (item.status == DownloadStatus.failed && item.errorMessage != null)
            Text(
              item.errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              maxLines: 1,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDownloading)
            IconButton(
              icon: const Icon(Icons.pause, color: Colors.amberAccent),
              onPressed: () => dlProvider.cancelDownload(item.postId),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white54),
            onPressed: () => dlProvider.removeDownload(item.postId),
          ),
        ],
      ),
      onTap: () {
        if (isCompleted && File(item.localPath).existsSync()) {
          // Play local downloaded file
          final localPost = PostModel(
            id: item.postId,
            score: 0,
            fileUrl: item.fileUrl,
            previewUrl: '',
            sampleUrl: '',
            tags: [],
            width: 0,
            height: 0,
            isDownloaded: true,
            localFilePath: item.localPath,
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(
                posts: [localPost],
                initialIndex: 0,
              ),
            ),
          );
        }
      },
    );
  }
}
