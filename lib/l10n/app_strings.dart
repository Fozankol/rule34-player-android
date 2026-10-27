import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class AppStrings {
  final String lang;
  AppStrings(this.lang);

  bool get isRu => lang == 'ru';

  static AppStrings of(BuildContext context) {
    try {
      final settings = Provider.of<SettingsProvider>(context);
      return AppStrings(settings.language);
    } catch (_) {
      return AppStrings('ru');
    }
  }

  // Common
  String get appTitle => 'Rule34 & Realbooru Player';
  String get library => isRu ? 'Медиатека' : 'Library';
  String get feed => isRu ? 'Лента' : 'Feed';
  String get favorites => isRu ? 'Избранное' : 'Favorites';
  String get downloads => isRu ? 'Загрузки' : 'Downloads';
  String get settings => isRu ? 'Настройки' : 'Settings';
  String get search => isRu ? 'Поиск' : 'Search';
  String get searchTags => isRu ? 'Поиск по тегам' : 'Search tags';
  String get filters => isRu ? 'Фильтры' : 'Filters';
  String get searchFilters => isRu ? 'Фильтры поиска' : 'Search Filters';
  String get retry => isRu ? 'Повторить' : 'Retry';
  String get apply => isRu ? 'Применить' : 'Apply';
  String get reset => isRu ? 'Сбросить' : 'Reset';
  String get close => isRu ? 'Закрыть' : 'Close';
  String get cancel => isRu ? 'Отмена' : 'Cancel';
  String get delete => isRu ? 'Удалить' : 'Delete';
  String get save => isRu ? 'Сохранить' : 'Save';
  String get copyTag => isRu ? 'Копировать тег' : 'Copy tag';
  String get tagCopied => isRu ? 'Тег скопирован' : 'Tag copied';
  String get nothingFound => isRu ? 'Ничего не найдено' : 'Nothing found';
  String get nothingFoundHint => isRu ? 'Попробуйте изменить теги или ослабить фильтры' : 'Try changing tags or relaxing filters';
  String get loadingError => isRu ? 'Ошибка загрузки' : 'Loading error';

  // Content type
  String get all => isRu ? 'Все' : 'All';
  String get videos => isRu ? 'Видео' : 'Videos';
  String get photos => isRu ? 'Фото' : 'Photos';
  String get contentType => isRu ? 'Тип контента' : 'Content Type';

  // Duration
  String get videoDuration => isRu ? 'Длительность видео' : 'Video Duration';
  String get anyDuration => isRu ? 'Любая' : 'Any';
  String get gt2min => isRu ? '> 2 мин' : '> 2 min';
  String get gt5min => isRu ? '> 5 мин' : '> 5 min';
  String get gt10min => isRu ? '> 10 мин' : '> 10 min';
  String get customDuration => isRu ? 'Своя...' : 'Custom...';
  String minMinutes(double m) => isRu ? 'От ${m.toStringAsFixed(1)} мин' : 'From ${m.toStringAsFixed(1)} min';

  // Score
  String get minLikes => isRu ? 'Минимум лайков' : 'Minimum Likes';
  String get anyScore => isRu ? 'Любой' : 'Any';

  // Sorting
  String get sorting => isRu ? 'Сортировка' : 'Sorting';
  String get newestFirst => isRu ? 'Сначала новые' : 'Newest first';
  String get byScore => isRu ? 'По лайкам (Score)' : 'By Likes (Score)';
  String get byDuration => isRu ? 'По длительности' : 'By Duration';

  // Player & Viewer
  String get tags => isRu ? 'Теги' : 'Tags';
  String get speed => isRu ? 'Скорость' : 'Speed';
  String get download => isRu ? 'Скачать' : 'Download';
  String get playbackError => isRu ? 'Ошибка воспроизведения' : 'Playback error';
  String get imageLoadError => isRu ? 'Ошибка загрузки изображения' : 'Failed to load image';
  String get noVideosAvailable => isRu ? 'Нет доступных видео' : 'No videos available';
  String get noFavoritesYet => isRu ? 'Пока нет избранного' : 'No favorites yet';
  String get noDownloadsYet => isRu ? 'Нет загруженных файлов' : 'No downloaded files';
  String get downloadStarted => isRu ? 'Загрузка начата' : 'Download started';
  String get alreadyDownloaded => isRu ? 'Файл уже скачан' : 'Already downloaded';
  String get fileSaved => isRu ? 'Файл сохранен' : 'File saved';
  String get sound => isRu ? 'Звук' : 'Sound';
  String get muted => isRu ? 'Без звука' : 'Muted';
  String get saved => isRu ? 'Сохранено' : 'Saved';
  String get loadingVideo => isRu ? 'Загружаем видео' : 'Loading video';
  String get nextVideo => isRu ? 'Следующее видео' : 'Next video';
  String get back => isRu ? 'Назад' : 'Back';
  String get hideControls => isRu ? 'Скрыть управление' : 'Hide controls';
  String get pause => isRu ? 'Пауза' : 'Pause';
  String get play => isRu ? 'Воспроизвести' : 'Play';
  String get errorDetails => isRu ? 'Подробности ошибки' : 'Error details';
  String get retryLoading => isRu ? 'Повторить загрузку' : 'Retry loading';
  String get failedToPlay => isRu ? 'Не удалось воспроизвести' : 'Failed to play';
  String get failedToLoad => isRu ? 'Видео не загрузилось' : 'Video failed to load';
  String get codecErrorText => isRu
      ? 'Видеодекодер устройства вернул ошибку. Попробуйте ещё раз или скачайте файл для другого плеера.'
      : 'Device video decoder returned an error. Try again or download the file for another player.';
  String get networkErrorText => isRu
      ? 'Проверьте соединение и повторите загрузку. Если файл недоступен, перейдите к следующему видео.'
      : 'Check your connection and try again. If unavailable, swipe to the next video.';

  // Settings
  String get languageTitle => isRu ? 'Язык' : 'Language';
  String get russian => 'Русский';
  String get english => 'English';
  String get contentSource => isRu ? 'Источник контента' : 'Content Source';
  String get authSection => isRu ? 'Доступ к Rule34 и Gelbooru' : 'Rule34 & Gelbooru Access';
  String get tagBlacklist => isRu ? 'Черный список тегов' : 'Tag Blacklist';
  String get storageAndCache => isRu ? 'Память и кэш' : 'Storage & Cache';
  String get clearMetadataCache => isRu ? 'Очистить кэш' : 'Clear Cache';
  String get clearCacheSubtitle => isRu ? 'Сбросить сохраненные данные о роликах и предзагрузки' : 'Reset saved video durations and preloaded cache';
  String get clearCacheConfirmTitle => isRu ? 'Очистить кэш?' : 'Clear Cache?';
  String get clearCacheConfirmText => isRu ? 'Все сохраненные данные о длительности и предзагруженные видео будут удалены.' : 'All cached video metadata and preloads will be deleted.';
  String get cacheCleared => isRu ? 'Кэш успешно очищен' : 'Cache cleared successfully';
}
