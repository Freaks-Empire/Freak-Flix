import 'package:xml/xml.dart';
import '../models/media_item.dart';
import '../models/cast_member.dart';

class SidecarService {
  
  /// Generates a standard NFO XML string for a movie or TV show.
  /// Compatible with Kodi/Emby/Plex scanners.
  static String generateNfo(MediaItem item) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    
    // Choose root element based on type
    final rootStart = item.type == MediaType.movie ? 'movie' : 'tvshow';
    
    builder.element(rootStart, nest: () {
      builder.element('title', nest: item.title ?? item.fileName);
      builder.element('originaltitle', nest: item.title ?? item.fileName);
      
      if (item.year != null) {
        builder.element('year', nest: item.year.toString());
      }
      
      // IDs
      if (item.tmdbId != null) {
        builder.element('uniqueid', attributes: {'type': 'tmdb', 'default': 'true'}, nest: item.tmdbId.toString());
        builder.element('tmdbid', nest: item.tmdbId.toString());
      }
      if (item.imdbId != null) {
         builder.element('uniqueid', attributes: {'type': 'imdb'}, nest: item.imdbId!);
         builder.element('imdbid', nest: item.imdbId!);
      }
      
      // Extended IDs for FreakFlix types
      if (item.anilistId != null) {
          builder.element('uniqueid', attributes: {'type': 'anilist'}, nest: item.anilistId.toString());
          builder.element('anilistid', nest: item.anilistId.toString());
      }
      
        // For Scenes (StashDB), often stored in <stashid> or custom tags
        // If the ID starts with 'stashdb:', strip prefix
        final stashId = item.stashId ?? (item.id.startsWith('stashdb:') ? item.id.replaceFirst('stashdb:', '') : null);
        if (stashId != null && stashId.isNotEmpty) {
          builder.element('uniqueid', attributes: {'type': 'stashdb', 'default': 'true'}, nest: stashId);
          builder.element('stashid', nest: stashId);
        }
      
      // Studio (if stored in overview as "Studio: X")
      if (item.overview != null && item.overview!.startsWith('Studio:')) {
         final studio = item.overview!.split('\n').first.replaceFirst('Studio: ', '').trim();
         if (studio.isNotEmpty) builder.element('studio', nest: studio);
      }

      // Plot
      if (item.overview != null) {
         builder.element('plot', nest: item.overview);
      }

      // Cast
      if (item.cast.isNotEmpty) {
         for (final CastMember member in item.cast) {
           builder.element('actor', nest: () {
             builder.element('name', nest: member.name);
             builder.element('role', nest: member.character);
             if (member.profileUrl != null) {
               builder.element('thumb', nest: member.profileUrl);
             }
           });
         }
      }

      // Artwork
      if (item.posterUrl != null) {
        builder.element('thumb', attributes: {'aspect': 'poster'}, nest: item.posterUrl);
      }
      if (item.backdropUrl != null) {
        builder.element('fanart', nest: () {
          builder.element('thumb', nest: item.backdropUrl);
        });
      }
      
      builder.element('dateadded', nest: DateTime.now().toIso8601String());
      builder.element('lockdata', nest: 'false'); 
    });

    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Parses an NFO string to extract IDs and basic info.
  /// Returns a partial MediaItem or null if parsing fails.
  static Map<String, dynamic>? parseNfo(String content) {
    try {
      final document = XmlDocument.parse(content);
      final root = document.rootElement;
      
      final tmdbIdStr = root.findElements('tmdbid').firstOrNull?.innerText ?? 
            root.findElements('uniqueid').where((e) => e.getAttribute('type') == 'tmdb').firstOrNull?.innerText;
      
      // Parse extended IDs
        final anilistIdStr = root.findElements('anilistid').firstOrNull?.innerText ??
                   root.findElements('uniqueid').where((e) => e.getAttribute('type') == 'anilist').firstOrNull?.innerText;

        final stashIdStr = root.findElements('stashid').firstOrNull?.innerText ??
                 root.findElements('uniqueid').where((e) => e.getAttribute('type') == 'stashdb').firstOrNull?.innerText;
        final studio = root.findElements('studio').firstOrNull?.innerText;
                           
      final title = root.findElements('title').firstOrNull?.innerText;
      final yearStr = root.findElements('year').firstOrNull?.innerText;
      
        if (tmdbIdStr != null || anilistIdStr != null || stashIdStr != null || title != null) {
          return {
             'tmdbId': int.tryParse(tmdbIdStr ?? ''),
             'anilistId': int.tryParse(anilistIdStr ?? ''),
           'stashId': stashIdStr,
             'title': title,
             'year': int.tryParse(yearStr ?? ''),
           'studio': studio,
          };
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
