/// lib/widgets/discover_filter_sheet.dart
import 'package:flutter/material.dart';
import '../models/discover_filter.dart';

class DiscoverFilterSheet extends StatefulWidget {
  final DiscoverFilter initial;

  const DiscoverFilterSheet({super.key, required this.initial});

  @override
  State<DiscoverFilterSheet> createState() => _DiscoverFilterSheetState();
}

class _DiscoverFilterSheetState extends State<DiscoverFilterSheet> {
  late DiscoverFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 420,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        margin: const EdgeInsets.only(right: 8, bottom: 8, top: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 24,
              color: Colors.black.withOpacity(0.18),
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filters', style: theme.textTheme.titleLarge),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _SectionLabel('Genre'),
              const SizedBox(height: 8),
              _GenreDropdown(
                value: _filter.genreId,
                onChanged: (id) =>
                    setState(() => _filter = _filter.copyWith(genreId: id)),
              ),
              const SizedBox(height: 16),
              const _SectionLabel('Decade'),
              const SizedBox(height: 8),
              _DecadeChips(
                value: _filter.decadeStartYear,
                onChanged: (year) => setState(
                  () => _filter = _filter.copyWith(decadeStartYear: year),
                ),
              ),
              const SizedBox(height: 16),
              const _SectionLabel('Ratings'),
              const SizedBox(height: 8),
              _RatingRow(
                value: (_filter.minRating ?? 0) ~/ 2,
                onChanged: (stars) => setState(
                  () => _filter = _filter.copyWith(minRating: stars * 2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('Ignore watched'),
                        Switch.adaptive(
                          value: _filter.ignoreWatched,
                          onChanged: (v) => setState(
                            () =>
                                _filter = _filter.copyWith(ignoreWatched: v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('Ignore watchlisted'),
                        Switch.adaptive(
                          value: _filter.ignoreWatchlisted,
                          onChanged: (v) => setState(
                            () => _filter =
                                _filter.copyWith(ignoreWatchlisted: v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _filter = DiscoverFilter.empty);
                      },
                      child: const Text('Reset all'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _filter),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Colors.grey[500]),
        ),
      );
}

class _GenreDropdown extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _GenreDropdown({
    required this.value,
    required this.onChanged,
  });

  static const _genres = [
    _Genre(28, 'Action'),
    _Genre(12, 'Adventure'),
    _Genre(16, 'Animation'),
    _Genre(35, 'Comedy'),
    _Genre(80, 'Crime'),
    _Genre(99, 'Documentary'),
    _Genre(18, 'Drama'),
    _Genre(10751, 'Family'),
    _Genre(14, 'Fantasy'),
    _Genre(36, 'History'),
    _Genre(27, 'Horror'),
    _Genre(10402, 'Music'),
    _Genre(9648, 'Mystery'),
    _Genre(10749, 'Romance'),
    _Genre(878, 'Science Fiction'),
    _Genre(10770, 'TV Movie'),
    _Genre(53, 'Thriller'),
    _Genre(10752, 'War'),
    _Genre(37, 'Western'),
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      value: value,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      hint: const Text('All genres'),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All genres')),
        ..._genres.map(
          (g) => DropdownMenuItem<int?>(
            value: g.id,
            child: Text(g.name),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _DecadeChips extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _DecadeChips({
    required this.value,
    required this.onChanged,
  });

  static const _decades = [1960, 1970, 1980, 1990, 2000, 2010, 2020];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          selected: value == null,
          label: const Text('Any'),
          onSelected: (_) => onChanged(null),
        ),
        ..._decades.map((year) {
          final selected = value == year;
          return ChoiceChip(
            selected: selected,
            label: Text('${year}s'),
            labelStyle: theme.textTheme.bodyMedium?.copyWith(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
            selectedColor: theme.colorScheme.primary,
            onSelected: (_) => onChanged(year),
          );
        }),
      ],
    );
  }
}

class _RatingRow extends StatelessWidget {
  final int value; // 0-5 stars
  final ValueChanged<int> onChanged;

  const _RatingRow({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(5, (i) {
        final selected = i < value;
        return IconButton(
          onPressed: () => onChanged(i + 1),
          icon: Icon(
            selected ? Icons.star : Icons.star_border,
            color: selected
                ? theme.colorScheme.secondary
                : theme.colorScheme.onSurfaceVariant,
          ),
          visualDensity: VisualDensity.compact,
        );
      }),
    );
  }
}

class _Genre {
  final int id;
  final String name;
  const _Genre(this.id, this.name);
}
