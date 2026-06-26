import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:alghaith_app/providers/app_provider.dart';
import 'package:alghaith_app/modules/taxi/providers/taxi_provider.dart';

class MockAppProvider extends Mock implements AppProvider {}

class MockTaxiProvider extends Mock implements TaxiProvider {}
