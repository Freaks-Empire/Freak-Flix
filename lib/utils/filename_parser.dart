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
    int? year; // Restored definition
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
    
    // --- 0.6) Namer / Stash Standard Pattern: Studio - Date - Title ---
    // Example: Brazzers - 2023.10.25 - Big Tits at Work
    // Regex: ^([^-]+)\s+-\s+(\d{4}[.-]\d{2}[.-]\d{2})\s+-\s+(.*)$
    final namerStudioDate = RegExp(r'^([^-]+)\s+-\s+(\d{4}[.-]\d{2}[.-]\d{2})\s+-\s+(.*)$').firstMatch(nameNoExt);
    if (namerStudioDate != null) {
      studio = namerStudioDate.group(1)?.trim();
      final dateStr = namerStudioDate.group(2)?.replaceAll('.', '-');
      date = DateTime.tryParse(dateStr ?? '');
      
      var remainder = namerStudioDate.group(3)?.trim() ?? '';
      
      // Performers check (w/ Performer)
      final perfMatch = RegExp(r'\(\s*w[_\s/]?\s*([^)]+)\)').firstMatch(remainder);
      if (perfMatch != null) {
         final rawPerfs = perfMatch.group(1)!;
         performers = rawPerfs.split(',').map((e) => e.trim()).toList();
         remainder = remainder.replaceAll(perfMatch.group(0)!, '').trim();
      }
      
      return ParsedMediaName(
        seriesTitle: remainder,
        movieTitle: remainder,
        studio: studio,
        date: date,
        year: date?.year,
        performers: performers,
      );
    }

    // --- 0.7) Namer / Stash Date First Pattern: Date - Studio - Title ---
    // Example: 2023.10.25 - Brazzers - Big Tits at Work
    final namerDateStudio = RegExp(r'^(\d{4}[.-]\d{2}[.-]\d{2})\s+-\s+([^-]+)\s+-\s+(.*)$').firstMatch(nameNoExt);
    if (namerDateStudio != null) {
       final dateStr = namerDateStudio.group(1)?.replaceAll('.', '-');
       date = DateTime.tryParse(dateStr ?? '');
       studio = namerDateStudio.group(2)?.trim();
       
       var remainder = namerDateStudio.group(3)?.trim() ?? '';
       
       // Performers check
       final perfMatch = RegExp(r'\(\s*w[_\s/]?\s*([^)]+)\)').firstMatch(remainder);
       if (perfMatch != null) {
          final rawPerfs = perfMatch.group(1)!;
          performers = rawPerfs.split(',').map((e) => e.trim()).toList();
          remainder = remainder.replaceAll(perfMatch.group(0)!, '').trim();
       }

       return ParsedMediaName(
        seriesTitle: remainder,
        movieTitle: remainder,
        studio: studio,
        date: date,
        year: date?.year,
        performers: performers,
      );
    }

    // --- 0.8) Check for Title - Date Pattern: Title - YYYY-MM-DD ---
    // Example: Dani Daniels loves Derrick Pierce - 2013-06-13
    final titleDateMatch = RegExp(r'^(.*)\s+-\s+(\d{4}-\d{2}-\d{2})$').firstMatch(nameNoExt);
    if (titleDateMatch != null) {
       final rawTitle = titleDateMatch.group(1)?.trim() ?? '';
       final dateStr = titleDateMatch.group(2);
       
       return ParsedMediaName(
          seriesTitle: rawTitle,
          movieTitle: rawTitle,
          date: DateTime.tryParse(dateStr ?? ''),
          year: DateTime.tryParse(dateStr ?? '')?.year,
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
      // We are stricter here: require "Ep", "Episode", "Part", "Vol", or a distinct " - " separator.
      // We DO NOT match simple dot-separated numbers like "Movie.3.mkv" anymore to preserve sequel numbers.
      final loose = RegExp(
        r'(?:^|[\s_])(?:ep(?:isode)?\.?|part|vol\.?)\s*(\d{1,3})(?!\d)', 
        caseSensitive: false,
      ).firstMatch(withoutTags);
      
      final strictHyphen = RegExp(r'\s-\s+(\d{1,3})(?!\d)').firstMatch(withoutTags);

      if (loose != null) {
        episode = int.tryParse(loose.group(1)!);
        season ??= 1;
        withoutTags = withoutTags.replaceFirst(loose.group(0)!, ' ');
      } else if (strictHyphen != null) {
        episode = int.tryParse(strictHyphen.group(1)!);
        season ??= 1;
        withoutTags = withoutTags.replaceFirst(strictHyphen.group(0)!, ' ');
      }
    }

    if (episode != null && season == null) {
      season = 1;
    }

    // --- 3) Date extraction (YYYY.MM.DD or DD.MM.YY) ---
    // User requested to remove dates like dd-mm-yy.
    // We try to find them, optionally parse them (if useful), and remove them from title.
    
    // YYYY-MM-DD or YYYY.MM.DD
    final dateMatchLong = RegExp(r'\b(\d{4}[.-]\d{2}[.-]\d{2})\b').firstMatch(withoutTags);
    if (dateMatchLong != null) {
       final dStr = dateMatchLong.group(1)!.replaceAll('.', '-');
       date = DateTime.tryParse(dStr);
       withoutTags = withoutTags.replaceFirst(dateMatchLong.group(0)!, ' ');
       if (year == null && date != null) year = date.year;
    }

    // DD-MM-YY or DD.MM.YY (Risky, but requested)
    // We'll require delimiters to be consistent.
    final dateMatchShort = RegExp(r'\b(\d{2}[.-]\d{2}[.-]\d{2})\b').firstMatch(withoutTags);
    if (dateMatchShort != null) {
       // We don't try to parse 2-digit years to DateTime to avoid 19xx/20xx ambiguity issues lightly,
       // but we DO remove it from the title.
       withoutTags = withoutTags.replaceFirst(dateMatchShort.group(0)!, ' ');
    }


    // --- 4) Year extraction (if not found in date) ---
    if (year == null) {
      final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(withoutTags);
      if (yearMatch != null) {
        year = int.tryParse(yearMatch.group(0)!);
        withoutTags = withoutTags.replaceFirst(yearMatch.group(0)!, ' ');
      }
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
