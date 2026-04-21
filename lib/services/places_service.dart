import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
//  PlacesService  —  Geoapify Places API
//
//  Fetches nearby cafes, parks, and shopping malls around a lat/lng.
//  Results are cached per coordinate to avoid redundant API calls.
// ─────────────────────────────────────────────────────────────────────────────

class NearbyPlace {
  final String name;
  final String category;       // 'cafe' | 'park' | 'shopping_mall'
  final String? address;
  final double? rating;
  final int? userRatingsTotal;
  final String? photoRef;      // Not supported by Geoapify — always null
  final String placeId;
  final double lat;
  final double lng;

  const NearbyPlace({
    required this.name,
    required this.category,
    required this.placeId,
    required this.lat,
    required this.lng,
    this.address,
    this.rating,
    this.userRatingsTotal,
    this.photoRef,
  });

  /// Opens this place in Google Maps
  String get mapsUrl =>
      'https://www.google.com/maps/search/?api=1'
          '&query=${Uri.encodeComponent(name)}'
          '&query_place_id=$placeId';

  IconData get icon {
    switch (category) {
      case 'cafe':          return Icons.local_cafe_rounded;
      case 'park':          return Icons.park_rounded;
      case 'shopping_mall': return Icons.shopping_bag_rounded;
      default:              return Icons.place_rounded;
    }
  }

  Color get color {
    switch (category) {
      case 'cafe':          return const Color(0xFFFFB300);
      case 'park':          return const Color(0xFF4CAF50);
      case 'shopping_mall': return const Color(0xFF42A5F5);
      default:              return Colors.white38;
    }
  }

  String get categoryLabel {
    switch (category) {
      case 'cafe':          return 'Café';
      case 'park':          return 'Park';
      case 'shopping_mall': return 'Shopping';
      default:              return 'Place';
    }
  }
}

class PlacesService {
  static const String _apiKey = '83e75edc7eae4902bd0467b0429d642b';
  static const String _baseUrl = 'https://api.geoapify.com/v2/places';

  // Cache per "lat,lng" key — survives widget rebuilds
  static final Map<String, List<NearbyPlace>> _cache = {};

  static const int _radius = 1500; // metres

  // Geoapify category → internal category key
  static const Map<String, String> _categoryMap = {
    'catering.cafe':      'cafe',
    'leisure.park':       'park',
    'commercial.shopping_mall': 'shopping_mall',
  };

  /// Returns nearby places. Uses cache if already fetched for this location.
  static Future<List<NearbyPlace>> fetchNearby({
    required double lat,
    required double lng,
  }) async {
    final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    if (_cache.containsKey(key)) return _cache[key]!;

    final List<NearbyPlace> results = [];

    for (final entry in _categoryMap.entries) {
      final geoapifyCategory = entry.key;
      final internalCategory = entry.value;

      try {
        final uri = Uri.parse(
          '$_baseUrl'
              '?categories=$geoapifyCategory'
              '&filter=circle:$lng,$lat,$_radius'
              '&limit=4'
              '&apiKey=$_apiKey',
        );

        final res = await http.get(uri).timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) {
          debugPrint('🗺 Geoapify [$geoapifyCategory]: HTTP ${res.statusCode}');
          continue;
        }

        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final features = body['features'] as List? ?? [];

        for (final feature in features) {
          try {
            final props = feature['properties'] as Map<String, dynamic>?;
            final geometry = feature['geometry'] as Map<String, dynamic>?;
            if (props == null || geometry == null) continue;

            final coords = geometry['coordinates'] as List?;
            if (coords == null || coords.length < 2) continue;

            final placeLng = (coords[0] as num).toDouble();
            final placeLat = (coords[1] as num).toDouble();

            final name = (props['name'] as String?) ??
                (props['address_line1'] as String?) ??
                'Place';

            final address = props['formatted'] as String? ??
                props['address_line2'] as String?;

            final placeId = (props['place_id'] as String?) ?? '';

            results.add(NearbyPlace(
              name: name,
              category: internalCategory,
              placeId: placeId,
              lat: placeLat,
              lng: placeLng,
              address: address,
              rating: null,           // Geoapify does not provide ratings
              userRatingsTotal: null,
              photoRef: null,         // Geoapify does not provide photo refs
            ));
          } catch (e) {
            debugPrint('Places parse error: $e');
          }
        }
      } catch (e) {
        debugPrint('Places fetch error [$geoapifyCategory]: $e');
      }
    }

    _cache[key] = results;
    return results;
  }

  /// Geoapify does not support photo references.
  /// This method is kept for API compatibility but will never be called
  /// since photoRef is always null.
  static String photoUrl(String ref) => '';

  static void clearCache() => _cache.clear();
}
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
//
// // ─────────────────────────────────────────────────────────────────────────────
// //  PlacesService  —  Foursquare Places API (V3)
// //
// //  Fetches nearby cafes, parks, and shopping malls around a lat/lng.
// //  Results are cached per coordinate to avoid redundant API calls.
// //
// //  Uses api.foursquare.com/v3 which accepts the fsq3 API key format.
// // ─────────────────────────────────────────────────────────────────────────────
//
// class NearbyPlace {
//   final String name;
//   final String category;       // 'cafe' | 'park' | 'shopping_mall'
//   final String? address;
//   final double? rating;
//   final int? userRatingsTotal;
//   final String? photoRef;      // Full photo URL (Foursquare prefix+size+suffix)
//   final String placeId;
//   final double lat;
//   final double lng;
//
//   const NearbyPlace({
//     required this.name,
//     required this.category,
//     required this.placeId,
//     required this.lat,
//     required this.lng,
//     this.address,
//     this.rating,
//     this.userRatingsTotal,
//     this.photoRef,
//   });
//
//   /// Opens this place in Google Maps
//   String get mapsUrl =>
//       'https://www.google.com/maps/search/?api=1'
//           '&query=${Uri.encodeComponent(name)}'
//           '&query_place_id=$placeId';
//
//   IconData get icon {
//     switch (category) {
//       case 'cafe':          return Icons.local_cafe_rounded;
//       case 'park':          return Icons.park_rounded;
//       case 'shopping_mall': return Icons.shopping_bag_rounded;
//       default:              return Icons.place_rounded;
//     }
//   }
//
//   Color get color {
//     switch (category) {
//       case 'cafe':          return const Color(0xFFFFB300);
//       case 'park':          return const Color(0xFF4CAF50);
//       case 'shopping_mall': return const Color(0xFF42A5F5);
//       default:              return Colors.white38;
//     }
//   }
//
//   String get categoryLabel {
//     switch (category) {
//       case 'cafe':          return 'Café';
//       case 'park':          return 'Park';
//       case 'shopping_mall': return 'Shopping';
//       default:              return 'Place';
//     }
//   }
// }
//
// class PlacesService {
//   // V3 endpoint — accepts fsq3 API keys directly (no Bearer prefix)
//   static const String _apiKey =
//       'fsq3SFjhUPafJG40a070M/T+FMmAkHhGAajE9aNqBBoXty4=';
//   static const String _baseUrl =
//       'https://api.foursquare.com/v3/places/search';
//
//   // Cache per "lat,lng" key — survives widget rebuilds
//   static final Map<String, List<NearbyPlace>> _cache = {};
//
//   static const int _radius = 1500; // metres
//
//   // Foursquare category IDs → internal category key
//   // 13032 = Café, 16032 = Park, 17114 = Shopping Mall
//   static const Map<String, String> _categoryMap = {
//     '13032': 'cafe',
//     '16032': 'park',
//     '17114': 'shopping_mall',
//   };
//
//   // V3 uses the raw API key in Authorization (no "Bearer" prefix)
//   static Map<String, String> get _headers => {
//     'Accept': 'application/json',
//     'Authorization': _apiKey,
//   };
//
//   /// Returns nearby places. Uses cache if already fetched for this location.
//   static Future<List<NearbyPlace>> fetchNearby({
//     required double lat,
//     required double lng,
//   }) async {
//     final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
//     if (_cache.containsKey(key)) return _cache[key]!;
//
//     final List<NearbyPlace> results = [];
//
//     for (final entry in _categoryMap.entries) {
//       final fsqCategory = entry.key;
//       final internalCategory = entry.value;
//
//       try {
//         final uri = Uri.parse(_baseUrl).replace(queryParameters: {
//           'll': '$lat,$lng',
//           'radius': '$_radius',
//           'categories': fsqCategory,
//           'limit': '4',
//           'fields': 'fsq_id,name,location,geocodes,rating,stats,photos',
//         });
//
//         final res = await http
//             .get(uri, headers: _headers)
//             .timeout(const Duration(seconds: 10));
//
//         if (res.statusCode != 200) {
//           debugPrint(
//               '🗺 Foursquare [$fsqCategory]: HTTP ${res.statusCode} — ${res.body}');
//           continue;
//         }
//
//         final body = jsonDecode(res.body) as Map<String, dynamic>;
//         final list = body['results'] as List? ?? [];
//
//         for (final p in list) {
//           try {
//             // Coordinates
//             final geocodes = p['geocodes'] as Map<String, dynamic>?;
//             final main = geocodes?['main'] as Map<String, dynamic>?;
//             final placeLat = (main?['latitude'] as num?)?.toDouble();
//             final placeLng = (main?['longitude'] as num?)?.toDouble();
//             if (placeLat == null || placeLng == null) continue;
//
//             // Address
//             final location = p['location'] as Map<String, dynamic>?;
//             final address = location?['formatted_address'] as String? ??
//                 location?['address'] as String?;
//
//             // Rating — Foursquare V3 returns 0–10, divide by 2 for 0–5 scale
//             final rawRating = (p['rating'] as num?)?.toDouble();
//             final rating = rawRating != null ? rawRating / 2.0 : null;
//
//             // Stats (total ratings count)
//             final stats = p['stats'] as Map<String, dynamic>?;
//             final userRatingsTotal = stats?['total_ratings'] as int?;
//
//             // Photo — build full URL from prefix + size + suffix
//             final photos = p['photos'] as List?;
//             String? photoRef;
//             if (photos != null && photos.isNotEmpty) {
//               final photo = photos[0] as Map<String, dynamic>?;
//               final prefix = photo?['prefix'] as String?;
//               final suffix = photo?['suffix'] as String?;
//               if (prefix != null && suffix != null) {
//                 photoRef = '${prefix}400x300$suffix';
//               }
//             }
//
//             results.add(NearbyPlace(
//               name: (p['name'] as String?) ?? 'Place',
//               category: internalCategory,
//               placeId: (p['fsq_id'] as String?) ?? '',
//               lat: placeLat,
//               lng: placeLng,
//               address: address,
//               rating: rating,
//               userRatingsTotal: userRatingsTotal,
//               photoRef: photoRef,
//             ));
//           } catch (e) {
//             debugPrint('Places parse error: $e');
//           }
//         }
//       } catch (e) {
//         debugPrint('Places fetch error [$fsqCategory]: $e');
//       }
//     }
//
//     _cache[key] = results;
//     return results;
//   }
//
//   /// Foursquare photo URLs are fully constructed during parsing.
//   /// photoRef IS the complete URL — this method is kept for API compatibility.
//   static String photoUrl(String ref) => ref;
//
//   static void clearCache() => _cache.clear();
// }