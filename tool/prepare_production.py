from pathlib import Path

p = Path('lib/production_main.dart')
s = p.read_text()
imp = "import 'package:share_plus/share_plus.dart';\n"
if "import 'password_pages.dart';" not in s:
    s = s.replace(imp, imp + "import 'password_pages.dart';\n", 1)
needle = "const SizedBox(height: 12), const Text('Temz Store • 09012533620', style: TextStyle(color: Colors.grey)),"
replacement = "const SizedBox(height: 6), Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())), child: const Text('Forgot Password?'))), const SizedBox(height: 4), const Text('Temz Store • 09012533620', style: TextStyle(color: Colors.grey)),"
if needle in s:
    s = s.replace(needle, replacement, 1)
menu_needle = "const Divider(), ListTile(leading: const Icon(Icons.logout), title: const Text('Log out'), onTap: () => supa.auth.signOut())"
menu_replacement = "const Divider(), ListTile(leading: const Icon(Icons.lock_reset), title: const Text('Change Password'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage()))), ListTile(leading: const Icon(Icons.logout), title: const Text('Log out'), onTap: () => supa.auth.signOut())"
if menu_needle in s:
    s = s.replace(menu_needle, menu_replacement, 1)
p.write_text(s)
