// Extracted from LibraryProvider — pure filtering, statistics,
// and grouping logic. All methods are static and stateless.
import '../models/media_item.dart';
import '../models/discover_type.dart';
import '../models/user_profile.dart';
import '../utils/filename_parser.dart';
import 'package:path/path.dart' as p;
import 'package:collection/collection.dart';

class LibraryFilterService {
  const LibraryFilterService._();

  // ── Type filters ───────────────────────────────────────────────────

  static List<MediaItem> filterMovies(
      List<MediaItem> items, bool enableAdult) {
    return enableAdult
        ? items.where((i) => i.type == MediaType.movie).toList()
        : items
            .where((i) => i.type == MediaType.movie && !i.isAdult)
            .toList();
  }

  static List<MediaItem> filterAdult(List<MediaItem> items) {
    return items.where((i) => i.isAdult).toList();
  }

  static List<MediaItem> filterTv(List<MediaItem> items, bool enableAdult) {
    return groupShows(enableAdult
        ? items.where((i) => i.type == MediaType.tv && !i.isAnime)
        : items
            .where((i) => i.type == MediaType.tv && !i.isAnime && !i.isAdult));
  }

  static List<MediaItem> filterAnime(List<MediaItem> items) {
    return groupShows(
        items.where((i) => i.type == MediaType.tv && i.isAnime));
  }

  static List<TvShowGroup> groupedTvShows(
      List<MediaItem> items, bool enableAdult) {
    return groupShowsToGroups(enableAdult
        ? items.where((i) => i.type == MediaType.tv && !i.isAnime)
        : items
            .where((i) => i.type == MediaType.tv && !i.isAnime && !i.isAdult));
  }

  static List<TvShowGroup> groupedAnimeShows(List<MediaItem> items) {
    return groupShowsToGroups(
        items.where((i) => i.type == MediaType.tv && i.isAnime));
  }

  // ── Continue watching / History ────────────────────────────────────

  static List<MediaItem> filterContinueWatching(
      List<MediaItem> items, bool enableAdult) {
    final pool = enableAdult
        ? items.where((i) => i.lastPositionSeconds > 0 && !i.isWatched)
        : items.where(
            (i) => i.lastPositionSeconds > 0 && !i.isWatched && !i.isAdult);
    return pool.toList();
  }

  static List<MediaItem> filterContinueWatchingDetailed(
      List<MediaItem> items) {
    return items.where((item) {
      if (item.lastPositionSeconds <= 0) return false;
      if (item.isWatched) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
  }

  static List<MediaItem> filterHistory(List<MediaItem> items) {
    return items.where((item) => item.isWatched).toList()
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
  }

  // ── Recently added / Top rated ─────────────────────────────────────

  static List<MediaItem> filterRecentlyAdded(
      List<MediaItem> items, bool enableAdult,
      {int limit = 20}) {
    final pool = enableAdult ? items : items.where((i) => !i.isAdult);
    final sorted = pool.toList()
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return sorted.take(limit).toList();
  }

  static List<MediaItem> filterTopRated(
      List<MediaItem> items, bool enableAdult,
      {int limit = 20}) {
    final pool = enableAdult ? items : items.where((i) => !i.isAdult);
    final sorted = pool.toList()
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return sorted.take(limit).toList();
  }

  // ── Recommendations ────────────────────────────────────────────────

  static List<MediaItem> getRecommendedLocal(
      List<MediaItem> items, DiscoverType type, bool enableAdult) {
    if (items.isEmpty) return [];

    var pool = enableAdult
        ? items.where((i) => !i.isWatched)
        : items.where((i) => !i.isWatched && !i.isAdult);

    switch (type) {
      case DiscoverType.movie:
        pool = pool.where((i) => i.type == MediaType.movie);
        break;
      case DiscoverType.tv:
        pool = pool.where((i) => i.type == MediaType.tv && !i.isAnime);
        break;
      case DiscoverType.anime:
        pool = pool.where((i) => i.isAnime);
        break;
      case DiscoverType.all:
      default:
        break;
    }

    final uniqueList = <MediaItem>[];
    final seenShows = <String>{};

    for (final item in pool) {
      if (item.type == MediaType.movie) {
        uniqueList.add(item);
      } else {
        final key = item.showKey ??
            item.tmdbId?.toString() ??
            item.title ??
            item.folderPath;
        if (!seenShows.contains(key)) {
          seenShows.add(key);
          uniqueList.add(item);
        }
      }
    }

    uniqueList.shuffle();
    return uniqueList.take(20).toList();
  }

  // ── Search ─────────────────────────────────────────────────────────

  static MediaItem? findByTmdbId(List<MediaItem> items, int tmdbId) {
    return items.firstWhereOrNull((i) => i.tmdbId == tmdbId);
  }

  // ── Statistics ─────────────────────────────────────────────────────

  static int calculateTotalWatchTime(List<MediaItem> items) {
    int total = 0;
    for (final item in items) {
      if (item.isWatched && item.runtimeMinutes != null) {
        total += item.runtimeMinutes! * 60;
      } else if (item.lastPositionSeconds > 0) {
        total += item.lastPositionSeconds;
      }
    }
    return total;
  }

  static int countWatchedMovies(List<MediaItem> items) =>
      items.where((i) => i.type == MediaType.movie && i.isWatched).length;

  static int countWatchedEpisodes(List<MediaItem> items) =>
      items.where((i) => i.type == MediaType.tv && i.isWatched).length;

  static Map<String, int> calculateGenreBreakdown(List<MediaItem> items) {
    final map = <String, int>{};
    for (final item
        in items.where((i) => i.isWatched || i.lastPositionSeconds > 0)) {
      for (final genre in item.genres) {
        map[genre] = (map[genre] ?? 0) + 1;
      }
    }
    return map;
  }

  static List<MapEntry<String, int>> topGenres(List<MediaItem> items,
      [int limit = 5]) {
    final sorted = calculateGenreBreakdown(items).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  static List<MediaItem> recentActivity(List<MediaItem> items) => items
      .where((i) => i.lastPositionSeconds > 0 || i.isWatched)
      .toList()
    ..sort((a, b) => b.lastModified.compareTo(a.lastModified));

  static Map<String, int> calculateWatchActivityByDay(
      Map<String, UserMediaData> userData) {
    final now = DateTime.now();
    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final activity = <String, int>{};

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      activity[dayNames[day.weekday % 7]] = 0;
    }

    for (final entry in userData.entries) {
      final ud = entry.value;
      if (ud.positionSeconds > 0 || ud.isWatched) {
        final watchDate = ud.lastUpdated;
        final dayDiff = now.difference(watchDate).inDays;

        if (dayDiff >= 0 && dayDiff < 7) {
          final dayName = dayNames[watchDate.weekday % 7];
          final minutes =
              ud.positionSeconds > 0 ? ud.positionSeconds ~/ 60 : 0;
          activity[dayName] =
              (activity[dayName] ?? 0) + (minutes > 0 ? minutes : 30);
        }
      }
    }

    return activity;
  }

  // ── Grouping helpers ───────────────────────────────────────────────

  static MediaType inferTypeFromPath(MediaItem item) {
    final fileName = p.basenameWithoutExtension(item.fileName).toLowerCase();
    final folderName = p.basename(item.folderPath).toLowerCase();
    final hasSeasonInFolder =
        RegExp(r'season[ _-]?\d{1,2}').hasMatch(folderName);
    final hasTvPattern =
        RegExp(r'[Ss]\d{1,2}[Ee]\d{1,3}').hasMatch(fileName) ||
            RegExp(r'(?:^|[\s._-])(?:ep(?:isode)?\s*)?\d{1,3}(?!\d)')
                .hasMatch(fileName) ||
            hasSeasonInFolder ||
            item.season != null ||
            item.episode != null;

    if (hasTvPattern) return MediaType.tv;
    return MediaType.movie;
  }

  static String seriesKey(MediaItem item) {
    if (item.showKey != null && item.showKey!.isNotEmpty) return item.showKey!;
    return item.folderPath.toLowerCase();
  }

  static List<MediaItem> groupShows(Iterable<MediaItem> source) {
    final map = <String, MediaItem>{};
    for (final item in source) {
      final key = seriesKey(item);
      final episodeEntry = EpisodeItem(
        season: item.season ?? 1,
        episode: item.episode,
        filePath: item.filePath,
      );

      if (!map.containsKey(key)) {
        map[key] = item.copyWith(
          showKey: item.showKey ?? key,
          episodes: [episodeEntry],
        );
        continue;
      }

      final existing = map[key]!;
      final updatedEpisodes = [...existing.episodes, episodeEntry];
      map[key] = existing.copyWith(
        title:
            existing.title?.isNotEmpty == true ? existing.title : item.title,
        posterUrl: existing.posterUrl ?? item.posterUrl,
        backdropUrl: existing.backdropUrl ?? item.backdropUrl,
        overview: existing.overview ?? item.overview,
        rating: existing.rating ?? item.rating,
        runtimeMinutes: existing.runtimeMinutes ?? item.runtimeMinutes,
        genres: existing.genres.isNotEmpty ? existing.genres : item.genres,
        isAnime: existing.isAnime || item.isAnime,
        tmdbId: existing.tmdbId ?? item.tmdbId,
        showKey: existing.showKey ?? key,
        episodes: updatedEpisodes,
      );
    }
    return map.values.toList();
  }

  static List<TvShowGroup> groupShowsToGroups(Iterable<MediaItem> source) {
    final map = <String, List<MediaItem>>{};
    for (final item in source) {
      final key = (item.showKey != null && item.showKey!.isNotEmpty)
          ? item.showKey!
          : item.folderPath.toLowerCase();
      map.putIfAbsent(key, () => []);
      map[key]!.add(item);
    }

    return map.entries.map((entry) {
      final episodes = entry.value;
      episodes.sort((a, b) {
        final sa = a.season ?? 0;
        final sb = b.season ?? 0;
        final ea = a.episode ?? 0;
        final eb = b.episode ?? 0;
        return sa != sb ? sa.compareTo(sb) : ea.compareTo(eb);
      });
      final first = episodes.first;
      final parsedFirst = FilenameParser.parse(first.fileName);
      final title = parsedFirst.seriesTitle.isNotEmpty
          ? parsedFirst.seriesTitle
          : (first.title?.isNotEmpty == true ? first.title! : first.fileName);
      final poster = episodes
          .firstWhere((e) => e.posterUrl != null, orElse: () => first)
          .posterUrl;
      final backdrop = episodes
          .firstWhere((e) => e.backdropUrl != null, orElse: () => first)
          .backdropUrl;
      final year = episodes
              .firstWhere((e) => e.year != null, orElse: () => first)
              .year ??
          parsedFirst.year;
      final isAnime = episodes.any((e) => e.isAnime);
      return TvShowGroup(
        title: title,
        isAnime: isAnime,
        showKey: entry.key,
        episodes: episodes,
        posterUrl: poster,
        backdropUrl: backdrop,
        year: year,
      );
    }).toList();
  }
}
