/// lib/utils/filename_parser.dart
class ParsedMediaName {
  final String seriesTitle;
  final String? movieTitle;
  final int? year;
  final int? season;
  final int? episode;

  final String? studio;
  final DateTime? date;
  final List<String> performers;

  const ParsedMediaName({
    required this.seriesTitle,
    this.movieTitle,
    this.year,
    this.season,
    this.episode,
    this.studio,
    this.date,
    this.performers = const [],
  });
}

class FilenameParser {
  // Parses filenames like:
  // "[SubsGroup] Aharen-san wa Hakarenai - 06 [1080p].mkv" -> title "Aharen-san wa Hakarenai", season 1, episode 6
  // "Aharen-san wa Hakarenai S01E06.mkv" -> title "Aharen-san wa Hakarenai", season 1, episode 6
  // "Some.Movie.2020.1080p.mkv" -> title "Some Movie", movie year 2020
  // "[Studio] - 2023.04.25 - Title (w_ Performer).mp4" -> studio "Studio", date 2023-04-25, title "Title", performers ["Performer"]
  static ParsedMediaName parse(String fileName) {
    String nameNoExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    String? studio;
    DateTime? date;
    List<String> performers = [];

    // --- 0) Check for Scene Release Pattern: [Studio] - YYYY.MM.DD - Title (w_ Performers) ---
    // Example: [Bang Bros] - 2023.04.25 - Barbie Gone Wild.mp4
    final sceneMatch = RegExp(r'^\[(.*?)\]\s*-\s*(\d{4}\.\d{2}\.\d{2})\s*-\s*(.*)$').firstMatch(nameNoExt);
    
    if (sceneMatch != null) {
      studio = sceneMatch.group(1)?.trim();
      final dateStr = sceneMatch.group(2)?.replaceAll('.', '-'); // 2023.04.25 -> 2023-04-25
      date = DateTime.tryParse(dateStr ?? '');
      
      var remainder = sceneMatch.group(3)?.trim() ?? '';
      
      // Check for (w_ Performer, Performer 2)
      // Matches "(w_ P1, P2)" or "(w P1, P2)" or similar variations if user specified "w_" specifically.
      // Based on screenshot: "(w_ Ivi Rein)"
      final perfMatch = RegExp(r'\(\s*w[_\s]\s*([^)]+)\)').firstMatch(remainder);
      if (perfMatch != null) {
        final rawPerfs = perfMatch.group(1)!;
        performers = rawPerfs.split(',').map((e) => e.trim()).toList();
        // Remove from title
        remainder = remainder.replaceAll(perfMatch.group(0)!, '').trim();
      }

      // Further clean up the title (remove resolution tags if any still persist, though usually clean in this format)
      // Strip any other brackets
       remainder = remainder
        .replaceAll(RegExp(r'\s*(\[.*?\]|\(.*?\))\s*'), ' ')
        .trim();

      return ParsedMediaName(
        seriesTitle: remainder,
        movieTitle: remainder,
        year: date?.year,
        studio: studio,
        date: date,
        performers: performers,
      );
    }

    // --- 0.5) Check for Underscore Pattern: _Studio_ - Title.mp4 ---
    // Example: _VR Edging_ - Barbie Let You Finish...
    final underscoreMatch = RegExp(r'^_([^_]+)_\s*-\s*(.*)$').firstMatch(nameNoExt);
    if (underscoreMatch != null) {
       studio = underscoreMatch.group(1)?.trim(); // VR Edging
       var remainder = underscoreMatch.group(2)?.trim() ?? '';
       
       // Check for (w_ Performer) in this format too?
       final perfMatch = RegExp(r'\(\s*w[_\s]\s*([^)]+)\)').firstMatch(remainder);
       if (perfMatch != null) {
          final rawPerfs = perfMatch.group(1)!;
          performers = rawPerfs.split(',').map((e) => e.trim()).toList();
          remainder = remainder.replaceAll(perfMatch.group(0)!, '').trim();
       }

       return ParsedMediaName(
          seriesTitle: remainder,
          movieTitle: remainder,
          studio: studio,
          performers: performers,
       );
    }


    // remove fansub tags [..] and (..)
    // Note: If we didn't match the specific scene pattern, we proceed with standard cleanup.
    var withoutTags = nameNoExt
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\([^\)]*\)'), ' ');

    int? season;
    int? episode;

    // --- 1) Sonarr-style "S01E01" and cut off AFTER it ---
    final seMatch =
        RegExp(r'[Ss](\d{1,2})[Ee](\d{1,3})').firstMatch(withoutTags);
    if (seMatch != null) {
      season = int.tryParse(seMatch.group(1)!);
      episode = int.tryParse(seMatch.group(2)!);

      // keep only the part BEFORE SxxEyy -> this is the series name
      withoutTags = withoutTags.substring(0, seMatch.start);
    } else {
      // --- 2) Fallback: loose "Ep 01" / "- 01" patterns ---
      final loose = RegExp(
        r'(?:^|[\s._-])(?:ep(?:isode)?\s*)?(\d{1,3})(?!\d)',
      ).firstMatch(withoutTags);
      if (loose != null) {
        episode = int.tryParse(loose.group(1)!);
        season ??= 1;
        // remove the matched chunk so it doesn't pollute the title
        withoutTags = withoutTags.replaceFirst(loose.group(0)!, ' ');
      }
    }

    if (episode != null && season == null) {
      season = 1;
    }

    // --- 3) Year extraction ---
    int? year;
    final yearMatch = RegExp(r'(19|20)\d{2}').firstMatch(withoutTags);
    if (yearMatch != null) {
      year = int.tryParse(yearMatch.group(0)!);
      withoutTags = withoutTags.replaceFirst(yearMatch.group(0)!, ' ');
    }

    // --- 4) Clean up title: remove junk / punctuation ---
    var cleaned = withoutTags
        // resolutions
        .replaceAll(
            RegExp(r'\b(480|720|1080|2160)[pi]\b', caseSensitive: false), ' ')
        // source / quality
        .replaceAll(
            RegExp(r'\b(bluray|bd|webrip|web-dl|hdrip|remux|dvdrip|dvd|vhs|hdtv)\b',
                caseSensitive: false),
            ' ')
        // codecs / audio
        .replaceAll(
            RegExp(r'\b(x264|x265|hevc|avc|aac|flac|ddp?\d?)\b',
                caseSensitive: false),
            ' ')
        // separators
        .replaceAll(RegExp(r'[._-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) cleaned = fileName;

    return ParsedMediaName(
      seriesTitle: cleaned,
      movieTitle: cleaned,
      year: year,
      season: season,
      episode: episode,
    );
  }
}
