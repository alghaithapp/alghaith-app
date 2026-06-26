/// Shared infrastructure — theme, network, images, repositories, account UI.
library common_module;

export '../../core/config/app_config.dart';
export '../../core/network/api_client.dart';
export '../../core/theme/app_theme.dart';
export '../../services/supabase_service.dart';
export '../../services/image_storage_service.dart';
export '../../data/repositories/database_repository.dart';
export 'screens/account_screen.dart';
export 'screens/account_full_screen.dart';
export 'screens/account_deletion_screen.dart';
export 'screens/customer_account_view.dart';
export 'screens/app_settings_screen.dart';
export 'screens/notifications_screen.dart';
export 'screens/addresses_screen.dart';
export 'screens/payment_methods_screen.dart';
export 'screens/language_selection_screen.dart';
export 'screens/force_update_screen.dart';
export 'widgets/account/account_page_header.dart';
export 'widgets/account/account_server_loading_view.dart';
