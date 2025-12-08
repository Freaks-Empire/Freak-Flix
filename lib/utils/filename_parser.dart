class ParsedMediaName {
  final String seriesTitle;
  final String? movieTitle;
  final int? year;
  final int? season;
  final int? episode;

  const ParsedMediaName({
    required this.seriesTitle,
    this.movieTitle,
    this.year,
    this.season,
    this.episode,
  });
}

class FilenameParser {
  // Parses filenames like:
  // "[SubsGroup] Aharen-san wa Hakarenai - 06 [1080p].mkv" -> title "Aharen-san wa Hakarenai", season 1, episode 6
  // "Aharen-san wa Hakarenai S01E06.mkv" -> title "Aharen-san wa Hakarenai", season 1, episode 6
  // "Some.Movie.2020.1080p.mkv" -> title "Some Movie", movie year 2020
  static ParsedMediaName parse(String fileName) {
    // strip extension
    final nameNoExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

    // remove fansub tags [..] and (..)
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
            RegExp(r'\b(bluray|bd|webrip|web-dl|hdrip|remux|dvdrip)\b',
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
