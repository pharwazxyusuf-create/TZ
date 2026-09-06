from pathlib import Path

p = Path('lib/tz_build.dart')
s = p.read_text(encoding='utf-8')

marker = 'class StockPage extends StatelessWidget {'
if marker in s:
    prefix = s.split(marker, 1)[0]
    replacement = r'''class StockPage extends StatelessWidget {
  const StockPage({super.key});
  @override
  Widget build(BuildContext context) {
    final future = db.from('products').select('id,name,price,central_stock').order('name');
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Stock error: ${snapshot.error}'));
        final rows = snapshot.data ?? <Map<String, dynamic>>[];
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const Text('Central Stock', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy)),
            const SizedBox(height: 10),
            for (final product in rows)
              Card(child: ListTile(
                title: Text('${product['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Selling price: ₦${product['price'] ?? 0}'),
                trailing: Text('${product['central_stock'] ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              )),
          ],
        );
      },
    );
  }
}
'''
    s = prefix + replacement

s = s.replace('Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey)', 'Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey)')

if "import 'package:flutter_svg/flutter_svg.dart';" not in s:
    s = s.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter_svg/flutter_svg.dart';")
if "import 'password_pages.dart';" not in s:
    s = s.replace("import 'package:supabase_flutter/supabase_flutter.dart';", "import 'package:supabase_flutter/supabase_flutter.dart';\nimport 'password_pages.dart';")
if "import 'admin_setup.dart';" not in s:
    s = s.replace("import 'password_pages.dart';", "import 'password_pages.dart';\nimport 'admin_setup.dart';")

# Replace the broken JPEG logo widget with a clean, self-contained SVG logo.
logo_start = s.find('class Logo extends StatelessWidget {')
login_start = s.find('class LoginPage extends StatefulWidget {')
if logo_start >= 0 and login_start > logo_start:
    logo = '''class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 90});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: SvgPicture.asset('assets/temz_logo_clean.svg', fit: BoxFit.contain),
  );
}

'''
    s = s[:logo_start] + logo + s[login_start:]

anchor = "SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : login, child: busy ? const CircularProgressIndicator() : const Text('SIGN IN'))),"
if "Forgot Password?" not in s and anchor in s:
    s = s.replace(anchor, anchor + "\n                          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())), child: const Text('Forgot Password?'))),\n                          TextButton(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSetupPage())), child: const Text('First-time admin setup')),")

old = "    } on AuthException catch (e) {\n      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));\n    } finally {"
new = "    } on AuthException catch (e) {\n      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));\n    } catch (_) {\n      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to connect to Temz Store. Please check your internet connection and try again.')));\n    } finally {"
if old in s:
    s = s.replace(old, new)

s = s.replace('stream: db.auth.onAuthStateChange,', 'stream: db.auth.onAuthStateChange.handleError((_) {}),')
p.write_text(s, encoding='utf-8')

manifest = Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
    m = manifest.read_text(encoding='utf-8')
    permission = '<uses-permission android:name="android.permission.INTERNET" />'
    if permission not in m:
        m = m.replace('<manifest ', '<manifest ' + '\n    ' + permission + '\n', 1)
        manifest.write_text(m, encoding='utf-8')

print('TZ final build fixes applied successfully.')
