import 'post_model.dart';

enum DurationFilterPreset {
  all,
  gt2min,
  gt5min,
  gt10min,
  custom,
}

enum ContentTypeFilter {
  all,
  videoOnly,
  photoOnly,
}

enum SortOption {
  newest,
  score,
  duration,
}

class FilterOptions {
  ContentTypeFilter contentType;
  DurationFilterPreset preset;
  double minDurationSeconds; // in seconds
  double? maxDurationSeconds; // in seconds, null for unlimited
  int minScore; // Minimum likes/score (0 = any)
  SortOption sortOption;
  List<String> searchTags;
  List<String> blacklistedTags;
  bool includeUnknownDuration;

  FilterOptions({
    this.contentType = ContentTypeFilter.videoOnly,
    DurationFilterPreset preset = DurationFilterPreset.gt2min,
    double? minDurationSeconds,
    this.maxDurationSeconds,
    this.minScore = 0,
    this.sortOption = SortOption.newest,
    List<String>? searchTags,
    List<String>? blacklistedTags,
    bool? includeUnknownDuration,
  })  : preset = preset,
        searchTags = searchTags ?? [],
        blacklistedTags = blacklistedTags ?? [],
        minDurationSeconds = minDurationSeconds ??
            (preset == DurationFilterPreset.all
                ? 0.0
                : preset == DurationFilterPreset.gt5min
                    ? 300.0
                    : preset == DurationFilterPreset.gt10min
                        ? 600.0
                        : 120.0),
        includeUnknownDuration = includeUnknownDuration ??
            (preset == DurationFilterPreset.all);

  void setPreset(DurationFilterPreset newPreset) {
    preset = newPreset;
    switch (newPreset) {
      case DurationFilterPreset.all:
        minDurationSeconds = 0;
        maxDurationSeconds = null;
        includeUnknownDuration = true;
        break;
      case DurationFilterPreset.gt2min:
        minDurationSeconds = 120.0;
        maxDurationSeconds = null;
        includeUnknownDuration = false;
        break;
      case DurationFilterPreset.gt5min:
        minDurationSeconds = 300.0;
        maxDurationSeconds = null;
        includeUnknownDuration = false;
        break;
      case DurationFilterPreset.gt10min:
        minDurationSeconds = 600.0;
        maxDurationSeconds = null;
        includeUnknownDuration = false;
        break;
      case DurationFilterPreset.custom:
        includeUnknownDuration = false;
        break;
    }
  }

  /// Evaluates whether a post matches content type, score, duration and blacklist rules
  bool matches(PostModel post) {
    // 1. Content type check
    if (contentType == ContentTypeFilter.videoOnly && !post.isVideo) {
      return false;
    }
    if (contentType == ContentTypeFilter.photoOnly && post.isVideo) {
      return false;
    }

    // 2. Score filter check
    if (minScore > 0 && post.score < minScore) {
      return false;
    }

    // 3. Blacklist check: if post contains any blacklisted tag, reject
    if (blacklistedTags.isNotEmpty) {
      final postTagsLower = post.tags.map((t) => t.toLowerCase()).toSet();
      for (final blocked in blacklistedTags) {
        final bLower = blocked.trim().toLowerCase();
        if (bLower.isNotEmpty && postTagsLower.contains(bLower)) {
          return false;
        }
      }
    }

    // 4. Duration check (only applies if post is a video and contentType is not photoOnly)
    if (post.isVideo && contentType != ContentTypeFilter.photoOnly) {
      if (preset == DurationFilterPreset.all && minDurationSeconds <= 0 && maxDurationSeconds == null) {
        return true;
      }

      if (post.duration == null || post.duration! <= 0) {
        return includeUnknownDuration;
      }

      if (post.duration! < minDurationSeconds) {
        return false;
      }

      if (maxDurationSeconds != null && post.duration! > maxDurationSeconds!) {
        return false;
      }
    }

    return true;
  }

  FilterOptions copyWith({
    ContentTypeFilter? contentType,
    DurationFilterPreset? preset,
    double? minDurationSeconds,
    double? maxDurationSeconds,
    int? minScore,
    SortOption? sortOption,
    List<String>? searchTags,
    List<String>? blacklistedTags,
    bool? includeUnknownDuration,
  }) {
    return FilterOptions(
      contentType: contentType ?? this.contentType,
      preset: preset ?? this.preset,
      minDurationSeconds: minDurationSeconds ?? this.minDurationSeconds,
      maxDurationSeconds: maxDurationSeconds ?? this.maxDurationSeconds,
      minScore: minScore ?? this.minScore,
      sortOption: sortOption ?? this.sortOption,
      searchTags: searchTags ?? List.from(this.searchTags),
      blacklistedTags: blacklistedTags ?? List.from(this.blacklistedTags),
      includeUnknownDuration: includeUnknownDuration ?? this.includeUnknownDuration,
    );
  }
}
