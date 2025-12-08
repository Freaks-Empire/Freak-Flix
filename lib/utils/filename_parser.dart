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
    final nameNoExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final withoutTags = nameNoExt
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\([^\)]*\)'), ' ');

    // Detect SxxEyy first
    final seMatch = RegExp(r'[Ss](\d{1,2})[Ee](\d{1,3})').firstMatch(withoutTags);
    int? season = seMatch != null ? int.tryParse(seMatch.group(1)!) : null;
    int? episode = seMatch != null ? int.tryParse(seMatch.group(2)!) : null;

    // Loose episode like "- 06" or "Ep06"
    if (episode == null) {
      final loose = RegExp(r'(?:^|[\s._-])(?:ep(?:isode)?\s*)?(\d{1,3})(?!\d)').firstMatch(withoutTags);
      if (loose != null) episode = int.tryParse(loose.group(1)!);
    }

    // Default season to 1 if we have an episode but no season.
    if (episode != null && season == null) season = 1;

    // Year extraction (best effort)
    int? year;
    final yearMatch = RegExp(r'(19|20)\d{2}').firstMatch(withoutTags);
    if (yearMatch != null) year = int.tryParse(yearMatch.group(0)!);

    // Remove episode/season markers, resolutions, codecs, and excess punctuation from title.
    var cleaned = withoutTags
        .replaceAll(RegExp(r'[Ss]\d{1,2}[Ee]\d{1,3}'), ' ')
        .replaceAll(RegExp(r'\b[Ee][Pp]?(?:isode)?\s*\d{1,3}\b'), ' ')
        .replaceAll(RegExp(r'\b(480|720|1080|2160)[pi]\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(bluray|bd|webrip|web-dl|hdrip|remux|dvdrip)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(x264|x265|hevc|avc|aac|flac|ddp?\d?)\b', caseSensitive: false), ' ')
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
