import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final query = _getReviewsQuery();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Reviews'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('all', 'All Reviews'),
                _buildFilterChip('5', '5 Stars'),
                _buildFilterChip('4', '4+ Stars'),
                _buildFilterChip('3', '3+ Stars'),
              ],
            ),
          ),

          // List + summary
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading reviews: ${snapshot.error}'),
                  );
                }

                final reviews = snapshot.data?.docs ?? [];

                if (reviews.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.rate_review_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Reviews Yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to leave a review!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Summary (from currently shown docs)
                final avg = _averageRating(reviews);
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reviews.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildSummaryCard(avg, reviews.length);
                    }
                    final review =
                        reviews[index - 1].data() as Map<String, dynamic>;
                    return _buildReviewCard(review);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- UI Helpers ----------

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepOrange : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(double average, int count) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            RatingBarIndicator(
              rating: average,
              itemBuilder: (context, _) =>
                  const Icon(Icons.star, color: Colors.amber),
              itemCount: 5,
              itemSize: 22,
            ),
            const SizedBox(width: 12),
            Text(
              '${average.toStringAsFixed(1)} out of 5',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text('$count review${count == 1 ? '' : 's'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = _toDouble(review['rating']);
    final reviewText = (review['review'] ?? '').toString();
    final timestamp = review['timestamp'] as Timestamp?;
    final customerName = (review['customerName'] ?? 'Anonymous')
        .toString()
        .trim();
    final mealLabel = _mealLabel(review);

    final dateStr = timestamp != null
        ? DateFormat('MMM d, yyyy').format(timestamp.toDate())
        : '';

    final avatarInitial = customerName.isNotEmpty
        ? customerName[0].toUpperCase()
        : 'A';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar, name/date, stars
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepOrange,
                  radius: 20,
                  child: Text(
                    avatarInitial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                RatingBarIndicator(
                  rating: rating,
                  itemBuilder: (context, _) =>
                      const Icon(Icons.star, color: Colors.amber),
                  itemCount: 5,
                  itemSize: 20.0,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Meal/Items tag
            if (mealLabel.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  mealLabel,
                  style: TextStyle(
                    color: Colors.deepOrange[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),

            // Review text
            if (reviewText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                reviewText,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],

            // Admin Reply Section
            if (review['adminReply'] != null && review['adminReply'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.reply,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Restaurant Response',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        if (review['adminReplyDate'] != null)
                          Text(
                            DateFormat('MMM d').format(
                              (review['adminReplyDate'] as Timestamp).toDate(),
                            ),
                            style: TextStyle(
                              color: Colors.orange.shade600,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      review['adminReply'].toString(),
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Footer summary
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.thumb_up_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${rating.toStringAsFixed(1)} out of 5 stars',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Query / Data helpers ----------

  Query _getReviewsQuery() {
    final col = FirebaseFirestore.instance.collection('order_reviews');

    // To avoid composite indexes:
    // - "All": sort by timestamp desc
    // - With filter: inequality on rating + orderBy rating desc
    if (_selectedFilter == 'all') {
      return col.orderBy('timestamp', descending: true);
    } else {
      final minRating = double.tryParse(_selectedFilter) ?? 0.0;
      return col
          .where('rating', isGreaterThanOrEqualTo: minRating)
          .orderBy('rating', descending: true);
    }
  }

  double _averageRating(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0.0;
    double sum = 0;
    var count = 0;
    for (final d in docs) {
      final r = _toDouble((d.data() as Map<String, dynamic>)['rating']);
      if (r > 0) {
        sum += r;
        count++;
      }
    }
    return count == 0 ? 0.0 : sum / count;
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0.0;
  }

  String _mealLabel(Map<String, dynamic> review) {
    // Prefer explicit mealName if present
    final mealName = (review['mealName'] ?? '').toString().trim();
    if (mealName.isNotEmpty) return mealName;

    // Otherwise, derive from items array: [{name, id, price}, ...]
    final items =
        (review['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final names = items
        .map((e) => (e['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (names.isEmpty) return '';

    if (names.length <= 2) return names.join(', ');
    final firstTwo = names.take(2).join(', ');
    return '$firstTwo +${names.length - 2} more';
  }
}
