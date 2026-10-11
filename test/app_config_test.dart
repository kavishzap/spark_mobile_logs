import 'package:flutter_test/flutter_test.dart';
import 'package:spark_sales/core/config/app_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parseEnvFile reads the public supabase keys', () {
    final values = parseEnvFile('''
# comment
NEXT_PUBLIC_SUPABASE_URL=https://example.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY="public-anon-key"
''');

    expect(values['NEXT_PUBLIC_SUPABASE_URL'], 'https://example.supabase.co');
    expect(values['NEXT_PUBLIC_SUPABASE_ANON_KEY'], 'public-anon-key');
  });

  test('the bundled .env configures the app', () async {
    await AppConfig.load();

    expect(AppConfig.instance.isConfigured, isTrue);
    expect(AppConfig.instance.supabaseUrl, startsWith('https://'));
  });
}
