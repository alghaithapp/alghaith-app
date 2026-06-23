import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_provider.dart';
import '../../../utils/driver_profile_fields.dart';
import '../models/taxi_request.dart';
import '../providers/taxi_provider.dart';

Future<bool> handleDriverAcceptRequest(
  BuildContext context,
  TaxiRequest request,
) async {
  final taxi = context.read<TaxiProvider>();
  final app = context.read<AppProvider>();
  final profile = app.driverProfile ?? const {};
  final plate = DriverProfileFields.plate(profile).isNotEmpty
      ? DriverProfileFields.plate(profile)
      : (profile['plateNumber'] as String?)?.trim() ?? '';

  final ok = await taxi.acceptRequest(
    request.id,
    driverName: DriverProfileFields.name(profile),
    vehicleModel: DriverProfileFields.vehicle(profile),
    plateNumber: plate,
  );

  if (!context.mounted) return ok;

  if (ok) {
    await app.refreshDriverTaxiRequests();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم قبول الطلب بنجاح',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.green,
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          taxi.error ?? 'تعذر قبول الطلب',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  return ok;
}

Future<bool> handleDriverRejectRequest(
  BuildContext context,
  TaxiRequest request,
) async {
  final taxi = context.read<TaxiProvider>();
  final ok = await taxi.rejectRequest(request.id);

  if (!context.mounted) return ok;

  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          taxi.error ?? 'تعذر رفض الطلب',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  return ok;
}
