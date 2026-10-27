import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/filter_options.dart';
import '../providers/feed_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late DurationFilterPreset _selectedPreset;
  late double _customMinutes;
  late SortOption _selectedSort;
  late int _selectedMinScore;

  @override
  void initState() {
    super.initState();
    final feed = context.read<FeedProvider>();
    _selectedPreset = feed.filterOptions.preset;
    _customMinutes = (feed.filterOptions.minDurationSeconds / 60.0).clamp(0.5, 60.0);
    _selectedSort = feed.filterOptions.sortOption;
    _selectedMinScore = feed.filterOptions.minScore;
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppStrings.of(context);
    final feed = context.watch<FeedProvider>();
    final isPhotoOnly = feed.filterOptions.contentType == ContentTypeFilter.photoOnly;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .85),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(
                  tr.searchFilters,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                )),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Duration Section (hidden or disabled if photo-only)
            if (!isPhotoOnly) ...[
              Text(
                tr.videoDuration,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPresetChip(tr.all, DurationFilterPreset.all),
                  _buildPresetChip(tr.gt2min, DurationFilterPreset.gt2min, isRecommended: true),
                  _buildPresetChip(tr.gt5min, DurationFilterPreset.gt5min),
                  _buildPresetChip(tr.gt10min, DurationFilterPreset.gt10min),
                  _buildPresetChip(tr.customDuration, DurationFilterPreset.custom),
                ],
              ),

              // Custom duration slider if custom selected
              if (_selectedPreset == DurationFilterPreset.custom) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'От',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '${_customMinutes.toStringAsFixed(1)} мин',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _customMinutes,
                  min: 0.5,
                  max: 60.0,
                  divisions: 119,
                  activeColor: AppTheme.accent,
                  inactiveColor: Colors.white24,
                  label: '${_customMinutes.toStringAsFixed(1)} мин',
                  onChanged: (val) {
                    setState(() {
                      _customMinutes = val;
                    });
                  },
                ),
              ],
              const Divider(color: Colors.white12, height: 24),
            ],

            // Minimum Score / Likes Section
            Text(
              tr.minLikes,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildScoreChip(tr.anyScore, 0),
                _buildScoreChip('10+', 10),
                _buildScoreChip('50+', 50),
                _buildScoreChip('100+', 100),
                _buildScoreChip('500+', 500),
              ],
            ),

            const Divider(color: Colors.white12, height: 24),

            // Sort Section
            Text(
              tr.sorting,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: [
                _buildSortChip(tr.newestFirst, SortOption.newest, Icons.access_time),
                _buildSortChip(tr.byScore, SortOption.score, Icons.favorite),
                if (!isPhotoOnly)
                  _buildSortChip(tr.byDuration, SortOption.duration, Icons.timer),
              ],
            ),

            const SizedBox(height: 24),

            // Apply button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: const Color(0xFF211B43),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final feedProv = context.read<FeedProvider>();
                  bool needsReload = false;

                  if (_selectedMinScore != feedProv.filterOptions.minScore) {
                    feedProv.filterOptions.minScore = _selectedMinScore;
                    needsReload = true;
                  }

                  if (_selectedSort != feedProv.filterOptions.sortOption) {
                    feedProv.filterOptions.sortOption = _selectedSort;
                    needsReload = true;
                  }

                  if (!isPhotoOnly) {
                    if (_selectedPreset == DurationFilterPreset.custom) {
                      feedProv.setCustomDurationRange(_customMinutes * 60.0, null);
                    } else {
                      feedProv.setDurationPreset(_selectedPreset);
                    }
                  }

                  if (needsReload) {
                    feedProv.loadInitial();
                  }

                  Navigator.pop(context);
                },
                child: Text(
                  tr.apply,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(
    String label,
    DurationFilterPreset preset, {
    bool isRecommended = false,
  }) {
    final isSelected = _selectedPreset == preset;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRecommended) ...[
            const Icon(Icons.star, size: 14, color: Colors.amberAccent),
            const SizedBox(width: 4),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: AppTheme.accent,
      backgroundColor: AppTheme.raised,
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF211B43) : AppTheme.text,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPreset = preset;
          });
        }
      },
    );
  }

  Widget _buildScoreChip(String label, int minScore) {
    final isSelected = _selectedMinScore == minScore;
    return ChoiceChip(
      avatar: Icon(
        Icons.favorite,
        size: 13,
        color: isSelected ? const Color(0xFF211B43) : AppTheme.error,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.accent,
      backgroundColor: AppTheme.raised,
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF211B43) : AppTheme.text,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedMinScore = minScore;
          });
        }
      },
    );
  }

  Widget _buildSortChip(String label, SortOption sort, IconData icon) {
    final isSelected = _selectedSort == sort;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? const Color(0xFF211B43) : AppTheme.text,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.accent,
      backgroundColor: AppTheme.raised,
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF211B43) : AppTheme.text,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedSort = sort;
          });
        }
      },
    );
  }
}
