import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart' show TZApp;

const _supabaseUrl = 'https://xztnrpfrrqfxqfmboruc.supabase.co';
const _supabasePublishableKey = 'sb_publishable_fFB3uYqNtygqBB_ARmKSdQ_qHU5SdTL';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabasePublishableKey,
  );
  runApp(const TZApp());
}
