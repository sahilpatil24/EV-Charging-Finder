import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/places_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NearbyPlacesWidget
//  Horizontal scroll list of nearby cafes, parks, malls.
//  Accepts a Future<List<NearbyPlace>> so the parent controls fetching.
// ─────────────────────────────────────────────────────────────────────────────

class NearbyPlacesWidget extends StatelessWidget {
  final Future<List<NearbyPlace>> placesFuture;

  const NearbyPlacesWidget({super.key, required this.placesFuture});

  Future<void> _open(NearbyPlace place) async {
    final uri = Uri.parse(place.mapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NearbyPlace>>(
      future: placesFuture,
      builder: (context, snap) {
        // Loading
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => const _SkeletonCard(),
            ),
          );
        }

        final places = snap.data ?? [];

        // Error / empty
        if (places.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(children: [
                Icon(Icons.location_off_rounded, color: Colors.white24, size: 18),
                SizedBox(width: 10),
                Text('No nearby places found',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              ]),
            ),
          );
        }

        return SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            itemCount: places.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _PlaceCard(
              place: places[i],
              onTap: () => _open(places[i]),
            ),
          ),
        );
      },
    );
  }
}

// ── Individual place card ──────────────────────────────────────────────────────
class _PlaceCard extends StatelessWidget {
  final NearbyPlace place;
  final VoidCallback onTap;

  const _PlaceCard({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = place.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo or color header
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: place.photoRef != null
                  ? Image.network(
                      PlacesService.photoUrl(place.photoRef!),
                      height: 64,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _ColorHeader(color: color, icon: place.icon),
                    )
                  : _ColorHeader(color: color, icon: place.icon),
            ),

            // Name + category + rating
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(place.categoryLabel,
                            style: TextStyle(
                                color: color,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (place.rating != null) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.star_rounded,
                            color: const Color(0xFFFFD600), size: 10),
                        const SizedBox(width: 2),
                        Text(place.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 10)),
                      ],
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorHeader extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _ColorHeader({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      width: double.infinity,
      color: color.withOpacity(0.12),
      child: Icon(icon, color: color, size: 26),
    );
  }
}

// ── Skeleton loading card ──────────────────────────────────────────────────────
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 150,
        decoration: BoxDecoration(
          color: Color.lerp(
              const Color(0xFF1E293B), const Color(0xFF2D3F55), _anim.value),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
