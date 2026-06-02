import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/merchant_models.dart';
import '../../providers/app_provider.dart';

class MerchantReviewsScreen extends StatelessWidget {
  const MerchantReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final reviews = provider.merchantReviews;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text(
          'التقييمات',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (reviews.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Icon(Icons.star_outline_rounded,
                      size: 48, color: Colors.deepOrange),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد تقييمات بعد',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else
            ...reviews.map(
              (review) => _ReviewCard(
                review: review,
                onReply: () => _showReplyDialog(context, review),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showReplyDialog(
    BuildContext context,
    MerchantReview review,
  ) async {
    final provider = context.read<AppProvider>();
    final controller = TextEditingController(text: review.reply ?? '');

    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'الرد على التقييم',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'اكتب ردك هنا',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (submitted == null) return;
    await provider.replyMerchantReview(review.id, submitted);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم حفظ الرد'),
        ),
      );
    }
  }
}

class _ReviewCard extends StatelessWidget {
  final MerchantReview review;
  final VoidCallback onReply;

  const _ReviewCard({
    required this.review,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.deepOrange.withValues(alpha: 0.10),
                child: Text(
                  review.stars.toString(),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    color: Colors.deepOrange,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review.date,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '★ ${review.stars}',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment,
            style: const TextStyle(fontFamily: 'Cairo', height: 1.4),
          ),
          if (review.reply != null && review.reply!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1E8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'ردك: ${review.reply}',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onReply,
              icon: const Icon(Icons.reply_rounded),
              label: Text(
                'الرد على التقييم',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
