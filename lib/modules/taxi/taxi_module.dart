/// Taxi module — public API.
///
/// Customer: request, waiting, live tracking, history, rating.
/// Driver: home, requests, trip, earnings.
library taxi_module;

export 'models/driver_model.dart';
export 'models/taxi_favorite_place.dart';
export 'models/taxi_request.dart';
export 'providers/taxi_provider.dart';
export 'screens/customer/taxi_customer_shell.dart';
export 'screens/driver/driver_home_screen.dart';
export 'utils/driver_readiness.dart';
export 'utils/taxi_fare_calculator.dart';
