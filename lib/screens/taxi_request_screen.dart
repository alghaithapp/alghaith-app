import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../utils/extensions.dart';

class TaxiRequestScreen extends StatefulWidget {
  const TaxiRequestScreen({super.key});

  @override
  State<TaxiRequestScreen> createState() => _TaxiRequestScreenState();
}

class _TaxiRequestScreenState extends State<TaxiRequestScreen> {
  final TextEditingController _pickupController =
      TextEditingController(text: 'المنصور - بغداد');
  final TextEditingController _dropoffController =
      TextEditingController(text: 'شارع الجامعة - بغداد');
  final TextEditingController _noteController =
      TextEditingController(text: 'يرجى الوصول إلى البوابة الرئيسية');

  String _selectedRideType = 'economy';
  String _selectedPayment = 'cash';

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isAr = appProvider.lang == 'ar';

    final rideTypes = [
      _RideType(
        id: 'economy',
        titleAr: 'اقتصادي',
        titleEn: 'Economy',
        subtitleAr: 'الأرخص والأسرع عادة',
        subtitleEn: 'Best value for quick trips',
        price: 4500,
        icon: CupertinoIcons.car_fill,
        color: Colors.green,
      ),
      _RideType(
        id: 'super',
        titleAr: 'سوبر',
        titleEn: 'Super',
        subtitleAr: 'خدمة أفضل وراحة أكثر',
        subtitleEn: 'Better service and a smoother ride',
        price: 6500,
        icon: CupertinoIcons.car_detailed,
        color: Colors.blue,
      ),
    ];

    final selectedRide =
        rideTypes.firstWhere((ride) => ride.id == _selectedRideType);
    final estimatedFare = selectedRide.price + 1500;
    final latestTaxiRequest =
        appProvider.taxiRequests.isNotEmpty ? appProvider.taxiRequests.first : null;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: Color(0x11000000))),
        middle: Text(
          isAr ? 'طلب تكسي' : 'Taxi Request',
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _MapPreviewCard(isAr: isAr),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _QuickStatsRow(
                  isAr: isAr,
                  estimatedTime: '6-10',
                  estimatedDistance: '4.2',
                  estimatedFare: estimatedFare,
                ),
              ),
            ),
            if (latestTaxiRequest != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _LiveStatusBanner(
                    isAr: isAr,
                    request: latestTaxiRequest,
                  ),
                ),
              ),
            if (latestTaxiRequest != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _SectionTitle(
                    title: isAr ? 'حالة الرحلة' : 'Trip status',
                    subtitle: isAr
                        ? 'تابع هنا آخر طلب تكسي أرسلته'
                        : 'Track the latest taxi request here',
                  ),
                ),
              ),
            if (latestTaxiRequest != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _TaxiStatusCard(
                    isAr: isAr,
                    request: latestTaxiRequest,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _SectionTitle(
                  title: isAr ? 'موقع الرحلة' : 'Trip locations',
                  subtitle: isAr
                      ? 'حدد نقطة الانطلاق والوصول'
                      : 'Set pickup and destination points',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _LocationCard(
                  isAr: isAr,
                  pickupController: _pickupController,
                  dropoffController: _dropoffController,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _SectionTitle(
                  title: isAr ? 'نوع التكسي' : 'Ride type',
                  subtitle: isAr
                      ? 'اختر الفئة المناسبة لرحلتك'
                      : 'Choose the ride that fits your trip',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 156,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  scrollDirection: Axis.horizontal,
                  itemCount: rideTypes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final ride = rideTypes[index];
                    final selected = ride.id == _selectedRideType;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedRideType = ride.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 150,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected
                              ? ride.color.withValues(alpha: 0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: selected ? ride.color : Colors.grey.shade200,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: ride.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child:
                                  Icon(ride.icon, color: ride.color, size: 24),
                            ),
                            const Spacer(),
                            Text(
                              isAr ? ride.titleAr : ride.titleEn,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isAr ? ride.subtitleAr : ride.subtitleEn,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                height: 1.35,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${ride.price.toPrice()} د.ع',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: selected ? ride.color : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _SectionTitle(
                  title: isAr ? 'الدفع والملاحظات' : 'Payment and notes',
                  subtitle: isAr
                      ? 'حدد طريقة الدفع وأضف ملاحظة للسائق'
                      : 'Choose payment and leave a note for the driver',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _PaymentCard(
                  isAr: isAr,
                  selectedPayment: _selectedPayment,
                  noteController: _noteController,
                  onPaymentSelected: (value) {
                    setState(() => _selectedPayment = value);
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: _RequestSummaryCard(
                  isAr: isAr,
                  rideName: isAr ? selectedRide.titleAr : selectedRide.titleEn,
                  fare: estimatedFare,
                  payment: _selectedPayment,
                  onRequest: () {
                    appProvider.addTaxiRequest(
                      TaxiRequest(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        requestNumber:
                            'TX-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
                        requestedAtAr:
                            'اليوم، ${TimeOfDay.now().format(context)}',
                        requestedAtEn:
                            'Today, ${TimeOfDay.now().format(context)}',
                        customerNameAr: appProvider.customerName,
                        customerNameEn: appProvider.customerName,
                        customerPhone: appProvider.customerPhone,
                        pickupAddressAr: _pickupController.text.trim(),
                        pickupAddressEn: _pickupController.text.trim(),
                        dropoffAddressAr: _dropoffController.text.trim(),
                        dropoffAddressEn: _dropoffController.text.trim(),
                        rideTypeId: selectedRide.id,
                        rideTypeAr: selectedRide.titleAr,
                        rideTypeEn: selectedRide.titleEn,
                        fare: estimatedFare,
                        statusKey: 'pending',
                        statusAr: 'بانتظار السائق',
                        statusEn: 'Waiting for driver',
                        noteAr: _noteController.text.trim(),
                        noteEn: _noteController.text.trim(),
                        paymentMethodAr: _selectedPayment == 'cash'
                            ? 'نقدًا'
                            : _selectedPayment == 'wallet'
                                ? 'محفظة'
                                : 'بطاقة',
                        paymentMethodEn: _selectedPayment == 'cash'
                            ? 'Cash'
                            : _selectedPayment == 'wallet'
                                ? 'Wallet'
                                : 'Card',
                      ),
                    );
                    showCupertinoDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: Text(isAr ? 'تم إرسال الطلب' : 'Request sent'),
                        content: Text(
                          isAr
                              ? 'واجهة تكسي تجريبية جاهزة. عند الربط الحقيقي ستظهر هنا حالة السائق ومسار الرحلة.'
                              : 'Taxi features are coming soon. Once connected to the backend, driver status and trip tracking will appear here.',
                        ),
                        actions: [
                          CupertinoDialogAction(
                            child: Text(isAr ? 'حسنًا' : 'OK'),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPreviewCard extends StatelessWidget {
  final bool isAr;

  const _MapPreviewCard({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MapPatternPainter(),
              ),
            ),
            Positioned(
              left: 18,
              top: 18,
              child: _FloatingTag(
                title: isAr ? 'السائقون قريبون' : 'Drivers nearby',
                color: Colors.green,
              ),
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: _FloatingTag(
                title: isAr ? 'متوسط الانتظار 4 د' : 'Avg wait 4 min',
                color: Colors.orange,
              ),
            ),
            Center(
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  CupertinoIcons.location_solid,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            const Positioned(
              left: 32,
              bottom: 38,
              child: _MapPin(color: Colors.redAccent, label: 'A'),
            ),
            const Positioned(
              right: 38,
              top: 58,
              child: _MapPin(color: Colors.green, label: 'B'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  final bool isAr;
  final String estimatedTime;
  final String estimatedDistance;
  final int estimatedFare;

  const _QuickStatsRow({
    required this.isAr,
    required this.estimatedTime,
    required this.estimatedDistance,
    required this.estimatedFare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatBox(
              title: isAr ? 'وقت الوصول المتوقع' : 'Estimated arrival',
              value: '$estimatedTime ${isAr ? 'دقيقة' : 'min'}',
              icon: CupertinoIcons.clock_fill,
              color: Colors.blue,
            ),
          ),
          Expanded(
            child: _StatBox(
              title: isAr ? 'المسافة' : 'Distance',
              value: '$estimatedDistance ${isAr ? 'كم' : 'km'}',
              icon: CupertinoIcons.map_fill,
              color: Colors.green,
            ),
          ),
          Expanded(
            child: _StatBox(
              title: isAr ? 'التكلفة' : 'Fare',
              value: '${estimatedFare.toPrice()} د.ع',
              icon: CupertinoIcons.money_dollar_circle_fill,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final bool isAr;
  final TextEditingController pickupController;
  final TextEditingController dropoffController;

  const _LocationCard({
    required this.isAr,
    required this.pickupController,
    required this.dropoffController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _LocationField(
            label: isAr ? 'نقطة الانطلاق' : 'Pickup location',
            icon: CupertinoIcons.circle_fill,
            iconColor: Colors.green,
            controller: pickupController,
          ),
          const SizedBox(height: 14),
          _LocationField(
            label: isAr ? 'الوجهة' : 'Destination',
            icon: CupertinoIcons.location_solid,
            iconColor: Colors.redAccent,
            controller: dropoffController,
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final bool isAr;
  final String selectedPayment;
  final TextEditingController noteController;
  final ValueChanged<String> onPaymentSelected;

  const _PaymentCard({
    required this.isAr,
    required this.selectedPayment,
    required this.noteController,
    required this.onPaymentSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'طريقة الدفع' : 'Payment method',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ChoiceChip(
                  label: isAr ? 'نقدًا' : 'Cash',
                  selected: selectedPayment == 'cash',
                  onTap: () => onPaymentSelected('cash'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SoonChip(
                  label: isAr ? 'محفظة' : 'Wallet',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SoonChip(
                  label: isAr ? 'بطاقة' : 'Card',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isAr ? 'ملاحظة للسائق' : 'Note for driver',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: noteController,
            maxLines: 3,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestSummaryCard extends StatelessWidget {
  final bool isAr;
  final String rideName;
  final int fare;
  final String payment;
  final VoidCallback onRequest;

  const _RequestSummaryCard({
    required this.isAr,
    required this.rideName,
    required this.fare,
    required this.payment,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade700, Colors.deepOrange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'ملخص الرحلة' : 'Trip summary',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: isAr ? 'الفئة' : 'Type',
            value: rideName,
          ),
          _SummaryRow(
            label: isAr ? 'الدفع' : 'Payment',
            value: _paymentLabel(payment, isAr),
          ),
          _SummaryRow(
            label: isAr ? 'السعر المتوقع' : 'Estimated fare',
            value: '${fare.toPrice()} د.ع',
            emphasize: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 15),
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              onPressed: onRequest,
              child: Text(
                isAr ? 'اطلب التكسي الآن' : 'Request taxi now',
                style: const TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _paymentLabel(String payment, bool isAr) {
    switch (payment) {
      case 'wallet':
        return isAr ? 'محفظة' : 'Wallet';
      case 'card':
        return isAr ? 'بطاقة' : 'Card';
      default:
        return isAr ? 'نقدًا' : 'Cash';
    }
  }
}

class _TaxiStatusCard extends StatelessWidget {
  final bool isAr;
  final TaxiRequest request;

  const _TaxiStatusCard({
    required this.isAr,
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    final isRejected = request.statusKey == 'rejected';
    final isCompleted = request.statusKey == 'completed';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  CupertinoIcons.car_detailed,
                  color: Colors.deepOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr
                          ? 'الطلب رقم ${request.requestNumber}'
                          : 'Request ${request.requestNumber}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAr ? request.requestedAtAr : request.requestedAtEn,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                text: isAr ? request.statusAr : request.statusEn,
                color: isRejected
                    ? Colors.red
                    : isCompleted
                        ? Colors.green
                        : Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _TaxiTimelineDot(
                  title: isAr ? 'تم قبول الطلب' : 'Request accepted',
                  subtitle: isAr
                      ? 'تظهر هذه المرحلة بعد موافقة السائق'
                      : 'Shown after the driver accepts the request',
                  color: Colors.blue,
                  icon: CupertinoIcons.checkmark_alt_circle_fill,
                  active: _isTaxiStepReached(request.statusKey, 'accepted'),
                  current: request.statusKey == 'accepted',
                  completed:
                      _isTaxiStepCompleted(request.statusKey, 'accepted'),
                ),
                _TaxiTimelineLine(
                  active: _isTaxiStepReached(request.statusKey, 'on_way'),
                ),
                _TaxiTimelineDot(
                  title: isAr ? 'السائق في الطريق' : 'Driver on the way',
                  subtitle: isAr
                      ? 'السيارة متجهة الآن إليك'
                      : 'The driver is heading to your location',
                  color: Colors.orange,
                  icon: CupertinoIcons.car_fill,
                  active: _isTaxiStepReached(request.statusKey, 'on_way'),
                  current: request.statusKey == 'on_way',
                  completed: _isTaxiStepCompleted(request.statusKey, 'on_way'),
                ),
                _TaxiTimelineLine(
                  active: _isTaxiStepReached(request.statusKey, 'arrived'),
                ),
                _TaxiTimelineDot(
                  title: isAr ? 'وصل للموقع' : 'Arrived at pickup',
                  subtitle: isAr
                      ? 'وصل السائق إلى نقطة الانطلاق'
                      : 'The driver arrived at the pickup point',
                  color: Colors.purple,
                  icon: CupertinoIcons.location_solid,
                  active: _isTaxiStepReached(request.statusKey, 'arrived'),
                  current: request.statusKey == 'arrived',
                  completed: _isTaxiStepCompleted(request.statusKey, 'arrived'),
                ),
                _TaxiTimelineLine(
                  active: _isTaxiStepReached(request.statusKey, 'picked_up'),
                ),
                _TaxiTimelineDot(
                  title: isAr ? 'استلام الزبون' : 'Customer picked up',
                  subtitle: isAr
                      ? 'تم استلامك من قبل السائق'
                      : 'You have been picked up by the driver',
                  color: Colors.teal,
                  icon: CupertinoIcons.person_crop_circle_badge_checkmark,
                  active: _isTaxiStepReached(request.statusKey, 'picked_up'),
                  current: request.statusKey == 'picked_up',
                  completed:
                      _isTaxiStepCompleted(request.statusKey, 'picked_up'),
                ),
                _TaxiTimelineLine(
                  active: _isTaxiStepReached(request.statusKey, 'completed'),
                ),
                _TaxiTimelineDot(
                  title: isAr ? 'تم الوصول' : 'Trip completed',
                  subtitle: isAr
                      ? 'انتهت الرحلة بنجاح'
                      : 'The trip ended successfully',
                  color: Colors.green,
                  icon: CupertinoIcons.check_mark_circled_solid,
                  active: _isTaxiStepReached(request.statusKey, 'completed'),
                  current: isCompleted,
                  completed: isCompleted,
                ),
              ],
            ),
          ),
          if (isRejected) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                isAr
                    ? 'تم رفض الطلب. يمكنك إنشاء طلب جديد من نفس الصفحة.'
                    : 'The request was rejected. You can place a new request from the same page.',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isTaxiStepReached(String statusKey, String stepKey) {
    const order = ['pending', 'accepted', 'on_way', 'arrived', 'picked_up', 'completed'];
    final statusIndex = order.indexOf(statusKey);
    final stepIndex = order.indexOf(stepKey);
    return statusIndex >= stepIndex && stepIndex != -1;
  }

  bool _isTaxiStepCompleted(String statusKey, String stepKey) {
    const order = ['accepted', 'on_way', 'arrived', 'picked_up', 'completed'];
    final statusIndex = order.indexOf(statusKey);
    final stepIndex = order.indexOf(stepKey);
    return statusIndex != -1 && stepIndex != -1 && statusIndex > stepIndex;
  }
}

class _LiveStatusBanner extends StatelessWidget {
  final bool isAr;
  final TaxiRequest request;

  const _LiveStatusBanner({
    required this.isAr,
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    final details = _liveNoticeFor(request.statusKey, isAr);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: details.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: details.colors.first.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(details.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details.subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.35,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          _StatusBadge(
            text: isAr ? request.statusAr : request.statusEn,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  _LiveNotice _liveNoticeFor(String statusKey, bool isAr) {
    switch (statusKey) {
      case 'accepted':
        return _LiveNotice(
          title: isAr ? 'تم قبول طلبك' : 'Your request was accepted',
          subtitle: isAr
              ? 'السائق بدأ مراجعة التفاصيل استعدادًا للانطلاق'
              : 'The driver is reviewing details before starting',
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          icon: CupertinoIcons.checkmark_alt_circle_fill,
        );
      case 'on_way':
        return _LiveNotice(
          title: isAr ? 'السائق في الطريق' : 'Driver is on the way',
          subtitle: isAr
              ? 'تابع الوصول المتوقع إلى موقعك'
              : 'Track the expected arrival to your location',
          colors: [Colors.orange.shade700, Colors.deepOrange.shade400],
          icon: CupertinoIcons.car_fill,
        );
      case 'arrived':
        return _LiveNotice(
          title: isAr ? 'وصل للموقع' : 'Arrived at pickup',
          subtitle: isAr
              ? 'السائق بانتظارك في نقطة الانطلاق'
              : 'The driver is waiting at the pickup point',
          colors: [Colors.purple.shade700, Colors.purple.shade400],
          icon: CupertinoIcons.location_solid,
        );
      case 'picked_up':
        return _LiveNotice(
          title: isAr ? 'استلام الزبون' : 'Customer picked up',
          subtitle: isAr
              ? 'بدأت الرحلة فعليًا مع السائق'
              : 'The trip has officially started',
          colors: [Colors.teal.shade700, Colors.teal.shade400],
          icon: CupertinoIcons.person_crop_circle_badge_checkmark,
        );
      case 'completed':
        return _LiveNotice(
          title: isAr ? 'تم الوصول' : 'Trip completed',
          subtitle: isAr
              ? 'اكتملت الرحلة بنجاح'
              : 'Your trip was completed successfully',
          colors: [Colors.green.shade700, Colors.green.shade400],
          icon: CupertinoIcons.check_mark_circled_solid,
        );
      case 'rejected':
        return _LiveNotice(
          title: isAr ? 'تم رفض الطلب' : 'Request rejected',
          subtitle: isAr
              ? 'يمكنك إرسال طلب جديد مباشرة'
              : 'You can create a new request right away',
          colors: [Colors.red.shade700, Colors.red.shade400],
          icon: CupertinoIcons.xmark_circle_fill,
        );
      default:
        return _LiveNotice(
          title: isAr ? 'بانتظار السائق' : 'Waiting for driver',
          subtitle: isAr
              ? 'أول سائق متاح سيظهر له طلبك'
              : 'The first available driver will see your request',
          colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade500],
          icon: CupertinoIcons.time,
        );
    }
  }
}

class _LiveNotice {
  final String title;
  final String subtitle;
  final List<Color> colors;
  final IconData icon;

  const _LiveNotice({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
  });
}

class _TaxiTimelineDot extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool active;
  final bool completed;
  final bool current;
  final Color color;
  final IconData icon;

  const _TaxiTimelineDot({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.completed,
    required this.current,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = completed || current ? color : Colors.grey.shade300;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: dotColor.withValues(alpha: active ? 0.12 : 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: dotColor, width: 1.2),
          ),
          child: Icon(icon, color: dotColor, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: active ? Colors.black87 : Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    height: 1.35,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TaxiTimelineLine extends StatelessWidget {
  final bool active;

  const _TaxiTimelineLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 19),
      width: 2,
      height: 16,
      decoration: BoxDecoration(
        color: active ? Colors.orange : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }
}

class _LocationField extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final TextEditingController controller;

  const _LocationField({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: controller,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.orange : const Color(0xFFF2F3F8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.orange : Colors.grey.shade200,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}

class _SoonChip extends StatelessWidget {
  final String label;

  const _SoonChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'قريباً',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingTag extends StatelessWidget {
  final String title;
  final Color color;

  const _FloatingTag({
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final String label;

  const _MapPin({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Container(
          width: 2,
          height: 18,
          color: color,
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            fontFamily: 'Cairo',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: Colors.white,
                fontSize: emphasize ? 15 : 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.08);

    for (double i = 20; i < size.width; i += 38) {
      canvas.drawLine(Offset(i, 0), Offset(i - 20, size.height), paint);
    }
    for (double y = 30; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 8), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RideType {
  final String id;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final int price;
  final IconData icon;
  final Color color;

  _RideType({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.price,
    required this.icon,
    required this.color,
  });
}
