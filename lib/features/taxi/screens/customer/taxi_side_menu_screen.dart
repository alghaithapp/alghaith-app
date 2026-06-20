import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/taxi_request.dart';
import '../../providers/taxi_provider.dart';
import '../../../../core/theme/app_colors.dart';

/// شاشة القائمة الجانبية للتكسي — طلبي الحالي، سجل الطلبات، تواصل معنا
class TaxiSideMenuScreen extends StatefulWidget {
  const TaxiSideMenuScreen({super.key});

  @override
  State<TaxiSideMenuScreen> createState() => _TaxiSideMenuScreenState();
}

class _TaxiSideMenuScreenState extends State<TaxiSideMenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<TaxiProvider>();
    await provider.loadActiveRequest();
    await provider.loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp() async {
    final phone = '964xxxxxxxxx'; // ضع رقم الدعم الفني هنا
    final message = Uri.encodeComponent('مرحباً، أحتاج مساعدة في خدمة التكسي');
    final uri = Uri.parse('https://wa.me/$phone?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح واتساب، تأكد من تثبيت التطبيق')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('خدمة التكسي'),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: const _BackButton(),
          leadingWidth: 80,
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.taxi_alert), text: 'طلبي الحالي'),
              Tab(icon: Icon(Icons.history), text: 'سجل الطلبات'),
              Tab(icon: Icon(Icons.headset_mic), text: 'تواصل معنا'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _CurrentRequestTab(),
            _HistoryTab(),
            _SupportTab(onWhatsAppTap: _openWhatsApp),
          ],
        ),
      ),
    );
  }
}

// ── التبويب الأول: الطلب الحالي ──

class _CurrentRequestTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TaxiProvider>(
      builder: (context, provider, _) {
        final request = provider.currentRequest;

        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (request == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.taxi_alert, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'لا يوجد طلب حالي',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'اذهب إلى شاشة طلب التكسي لإنشاء طلب جديد',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // بطاقة حالة الطلب
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    // أيقونة الحالة
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: _statusIconColor(request.statusKey).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _statusIcon(request.statusKey),
                        color: _statusIconColor(request.statusKey),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusLabel(request.statusKey),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _statusIconColor(request.statusKey),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (request.requestNumber.isNotEmpty)
                      Text(
                        'رقم الطلب: ${request.requestNumber}',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // تفاصيل الرحلة
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تفاصيل الرحلة',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const Divider(),
                    _detailRow(Icons.my_location, 'من', request.pickupAddress),
                    const SizedBox(height: 8),
                    _detailRow(Icons.place, 'إلى', request.dropoffAddress),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.straighten, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'المسافة: ${request.distanceKm.toStringAsFixed(1)} كم',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                        ),
                        const Spacer(),
                        const Icon(Icons.payments, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          '${request.fare} د.ع',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ],
                    ),
                    if (request.taxiTypeLabelAr.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.local_taxi, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            request.taxiTypeLabelAr,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // معلومات السائق إن وجدت
              if (request.driverName != null && request.driverName!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'معلومات السائق',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const Divider(),
                      _detailRow(Icons.person, 'الاسم', request.driverName ?? ''),
                      if (request.driverVehicleInfo != null && request.driverVehicleInfo!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _detailRow(Icons.directions_car, 'السيارة', request.driverVehicleInfo ?? ''),
                      ],
                      if (request.driverPhone != null && request.driverPhone!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _detailRow(Icons.phone, 'الهاتف', request.driverPhone ?? ''),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '$label:',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  IconData _statusIcon(String key) {
    switch (key) {
      case 'pending': return Icons.hourglass_empty;
      case 'accepted': return Icons.directions_car;
      case 'arrived': return Icons.location_on;
      case 'picked_up': return Icons.trip_origin;
      case 'completed': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.info;
    }
  }

  Color _statusIconColor(String key) {
    switch (key) {
      case 'pending': return const Color(0xFFF9A825);
      case 'accepted': return AppColors.primary;
      case 'arrived': return const Color(0xFF2E7D32);
      case 'picked_up': return const Color(0xFF145B66);
      case 'completed': return const Color(0xFF2E7D32);
      case 'cancelled': return const Color(0xFFC62828);
      default: return Colors.grey;
    }
  }

  String _statusLabel(String key) {
    switch (key) {
      case 'pending': return 'بانتظار سائق';
      case 'accepted': return 'السائق في الطريق';
      case 'arrived': return 'السائق في مكان الالتقاء';
      case 'picked_up': return 'تم الاستلام';
      case 'completed': return 'اكتملت الرحلة';
      case 'cancelled': return 'ملغية';
      default: return key;
    }
  }
}

// ── التبويب الثاني: سجل الطلبات ──

class _HistoryTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TaxiProvider>(
      builder: (context, provider, _) {
        final requests = provider.requests
            .where((r) => r.isCompleted || r.isCancelled)
            .toList();

        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'لا توجد طلبات سابقة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'قم برحلة جديدة لتظهر هنا',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadHistory(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, index) => _HistoryTripCard(request: requests[index]),
          ),
        );
      },
    );
  }
}

class _HistoryTripCard extends StatelessWidget {
  final TaxiRequest request;
  const _HistoryTripCard({required this.request});

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = request.isCompleted;
    final statusColor = isCompleted ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final statusText = isCompleted ? 'مكتمل' : 'ملغي';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // السطر الأول: رقم الطلب + التاريخ
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    request.requestNumber.isNotEmpty ? request.requestNumber : '---',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF145B66)),
                  ),
                ),
                const Spacer(),
                Text(_formatDate(request.completedAt ?? request.acceptedAt),
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 10),

            // من → إلى
            Row(
              children: [
                const Icon(Icons.my_location, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(request.pickupAddress,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.place, size: 14, color: AppColors.accent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(request.dropoffAddress,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // السطر الأخير: مسافة + سعر + حالة
            Row(
              children: [
                Icon(Icons.straighten, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('${request.distanceKm.toStringAsFixed(1)} كم',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey[600])),
                const SizedBox(width: 16),
                Icon(Icons.payments, size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('${request.fare} د.ع',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusText,
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ],
            ),

            // معلومات السائق
            if (request.driverName != null && request.driverName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(request.driverName!,
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey[500])),
                  if (request.driverVehicleInfo != null && request.driverVehicleInfo!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.directions_car, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(request.driverVehicleInfo!,
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── التبويب الثالث: تواصل مع الدعم الفني ──

class _SupportTab extends StatelessWidget {
  final VoidCallback onWhatsAppTap;
  const _SupportTab({required this.onWhatsAppTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat,
                size: 40,
                color: Color(0xFF25D366),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'تواصل مع الدعم الفني',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'لديك استفسار أو مشكلة؟ فريق الدعم الفني جاهز لمساعدتك عبر واتساب.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: onWhatsAppTap,
                icon: const Icon(Icons.message, color: Colors.white),
                label: const Text(
                  'راسلنا على واتساب',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ساعات العمل: ٨ صباحاً - ١٠ مساءً',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر رجوع — بنفس مقاس زر القائمة الجانبية (مثل شاشة طلب تكسي)
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(14),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 28,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
