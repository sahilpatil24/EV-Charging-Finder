import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  StationReviewsScreen
//
//  Firestore schema:
//  station_reviews/{reviewId}
//    - stationId    : String
//    - stationTitle : String
//    - userId       : String
//    - userName     : String
//    - rating       : int  (1–5)
//    - comment      : String
//    - createdAt    : Timestamp
// ─────────────────────────────────────────────────────────────────────────────

class StationReviewsScreen extends StatefulWidget {
  final String stationId;
  final String stationTitle;

  const StationReviewsScreen({
    super.key,
    required this.stationId,
    required this.stationTitle,
  });

  @override
  State<StationReviewsScreen> createState() => _StationReviewsScreenState();
}

class _StationReviewsScreenState extends State<StationReviewsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reviews',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
            Text(widget.stationTitle,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showAddReviewSheet(context),
            icon: const Icon(Icons.rate_review_rounded,
                color: Color(0xFF00C853), size: 16),
            label: const Text('Write',
                style: TextStyle(color: Color(0xFF00C853), fontSize: 13)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('station_reviews')
            .where('stationId', isEqualTo: widget.stationId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00C853)));
          }

          final allDocs = snap.data?.docs ?? [];
          // Sort client-side by createdAt descending
          final docs = allDocs.toList()
            ..sort((a, b) {
              final at = (a.data() as Map)['createdAt'] as Timestamp?;
              final bt = (b.data() as Map)['createdAt'] as Timestamp?;
              if (at == null || bt == null) return 0;
              return bt.compareTo(at);
            });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.star_outline_rounded,
                        color: Colors.white24, size: 48),
                  ),
                  const SizedBox(height: 16),
                  const Text('No reviews yet',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Be the first to review this station',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showAddReviewSheet(context),
                    icon: const Icon(Icons.rate_review_rounded, size: 16),
                    label: const Text('Write a Review'),
                  ),
                ],
              ),
            );
          }

          // Compute average
          final ratings =
              docs.map((d) => (d.data() as Map)['rating'] as int? ?? 0).toList();
          final avg = ratings.isEmpty
              ? 0.0
              : ratings.reduce((a, b) => a + b) / ratings.length;

          return Column(
            children: [
              // Rating summary banner
              _RatingSummary(average: avg, count: docs.length, ratings: ratings),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final currentUid =
                        FirebaseAuth.instance.currentUser?.uid ?? '';
                    final isOwn = d['userId'] == currentUid;
                    return _ReviewCard(
                      data: d,
                      isOwn: isOwn,
                      onDelete: isOwn
                          ? () => _deleteReview(docs[i].id)
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00C853),
        foregroundColor: Colors.black,
        onPressed: () => _showAddReviewSheet(context),
        icon: const Icon(Icons.star_rounded, size: 18),
        label: const Text('Add Review',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _deleteReview(String docId) async {
    await FirebaseFirestore.instance
        .collection('station_reviews')
        .doc(docId)
        .delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review deleted')));
    }
  }

  void _showAddReviewSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddReviewSheet(
        stationId: widget.stationId,
        stationTitle: widget.stationTitle,
      ),
    );
  }
}

// ── Rating summary bar ─────────────────────────────────────────────────────────
class _RatingSummary extends StatelessWidget {
  final double average;
  final int count;
  final List<int> ratings;

  const _RatingSummary(
      {required this.average, required this.count, required this.ratings});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF00C853).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Big average number
          Column(
            children: [
              Text(average.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold)),
              _StarRow(rating: average.round(), size: 18),
              const SizedBox(height: 4),
              Text('$count review${count != 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 24),
          // Bar chart per star
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final cnt = ratings.where((r) => r == star).length;
                final frac = count == 0 ? 0.0 : cnt / count;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Text('$star',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                    const SizedBox(width: 4),
                    Icon(Icons.star_rounded,
                        color: const Color(0xFFFFD600), size: 10),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 6,
                          backgroundColor:
                              const Color(0xFF0F172A),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFFD600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                        width: 20,
                        child: Text('$cnt',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10))),
                  ]),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual review card ─────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isOwn;
  final VoidCallback? onDelete;

  const _ReviewCard({required this.data, required this.isOwn, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = data['userName'] as String? ?? 'Anonymous';
    final rating = data['rating'] as int? ?? 0;
    final comment = data['comment'] as String? ?? '';
    final ts = data['createdAt'] as Timestamp?;
    final dateStr = ts != null
        ? DateFormat('MMM d, yyyy').format(ts.toDate())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOwn
              ? const Color(0xFF00C853).withOpacity(0.3)
              : Colors.white12,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Avatar circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Color(0xFF00C853),
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                if (isOwn) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('You',
                        style: TextStyle(
                            color: Color(0xFF00C853),
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              Text(dateStr,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white24, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ]),
        const SizedBox(height: 10),
        _StarRow(rating: rating, size: 16),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(comment,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.4)),
        ],
      ]),
    );
  }
}

// ── Star row widget ────────────────────────────────────────────────────────────
class _StarRow extends StatelessWidget {
  final int rating;
  final double size;

  const _StarRow({required this.rating, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          color: const Color(0xFFFFD600),
          size: size,
        );
      }),
    );
  }
}

// ── Add review bottom sheet ────────────────────────────────────────────────────
class _AddReviewSheet extends StatefulWidget {
  final String stationId;
  final String stationTitle;

  const _AddReviewSheet(
      {required this.stationId, required this.stationTitle});

  @override
  State<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<_AddReviewSheet> {
  int _selectedRating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }

    setState(() => _submitting = true);

    final user = FirebaseAuth.instance.currentUser!;
    // Get display name from Firestore if available
    String userName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (profileDoc.exists) {
        final uname = profileDoc.data()?['username'] as String?;
        if (uname != null && uname.isNotEmpty) userName = uname;
      }
    } catch (_) {}

    await FirebaseFirestore.instance.collection('station_reviews').add({
      'stationId': widget.stationId,
      'stationTitle': widget.stationTitle,
      'userId': user.uid,
      'userName': userName,
      'rating': _selectedRating,
      'comment': _commentCtrl.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted! ⭐'),
          backgroundColor: Color(0xFF00C853),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Write a Review',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(widget.stationTitle,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 20),

            // Star selector
            const Text('Your Rating',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(5, (i) {
                final starVal = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRating = starVal),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: AnimatedScale(
                      scale: _selectedRating >= starVal ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        _selectedRating >= starVal
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFFFD600),
                        size: 36,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            if (_selectedRating > 0)
              Text(
                [
                  '',
                  'Poor',
                  'Fair',
                  'Good',
                  'Very Good',
                  'Excellent'
                ][_selectedRating],
                style: const TextStyle(
                    color: Color(0xFFFFD600),
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 16),

            // Comment field
            const Text('Your Comment (optional)',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              maxLength: 300,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: const Color(0xFF00C853),
              decoration: InputDecoration(
                hintText:
                    'Share your experience with this charging station…',
                hintStyle:
                    const TextStyle(color: Colors.white24, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                counterStyle:
                    const TextStyle(color: Colors.white24, fontSize: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00C853)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Text('Submit Review',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact rating summary for the station bottom sheet ───────────────────────
class StationRatingBadge extends StatelessWidget {
  final String stationId;

  const StationRatingBadge({super.key, required this.stationId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('station_reviews')
          .where('stationId', isEqualTo: stationId)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.star_outline_rounded,
                  color: Colors.white24, size: 13),
              SizedBox(width: 4),
              Text('No reviews',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          );
        }

        final ratings = docs
            .map((d) => (d.data() as Map)['rating'] as int? ?? 0)
            .toList();
        final avg = ratings.reduce((a, b) => a + b) / ratings.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD600).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFFFFD600).withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star_rounded,
                color: Color(0xFFFFD600), size: 13),
            const SizedBox(width: 4),
            Text(avg.toStringAsFixed(1),
                style: const TextStyle(
                    color: Color(0xFFFFD600),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 3),
            Text('(${docs.length})',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 10)),
          ]),
        );
      },
    );
  }
}
