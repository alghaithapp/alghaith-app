import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/merchant_models.dart';
import '../../providers/app_provider.dart';

class MerchantReviewsScreen extends StatelessWidget {
  const MerchantReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAr = provider.lang == 'ar';
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
                    isAr ? 'لا توجد تقييمات بعد' : 'No reviews yet',
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
                isAr: isAr,
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
    final isAr = provider.lang == 'ar';
    final controller = TextEditingController(text: review.reply ?? '');

    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isAr ? 'الرد على التقييم' : 'Reply to review',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: isAr ? 'اكتب ردك هنا' : 'Write your reply here',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(isAr ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: Text(isAr ? 'حفظ' : 'Save'),
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
          content: Text(isAr ? 'تم حفظ الرد' : 'Reply saved'),
        ),
      );
    }
  }
}

class _ReviewCard extends StatelessWidget {
  final MerchantReview review;
  final bool isAr;
  final VoidCallback onReply;

  const _ReviewCard({
    required this.review,
    required this.isAr,
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
                isAr ? 'ردك: ${review.reply}' : 'Your reply: ${review.reply}',
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
                isAr ? 'الرد على التقييم' : 'Reply to review',
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
