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

# Replace query-builder values that were being passed to List.from/Future.value.
s = s.replace("Future<List<Map<String,dynamic>>> load()=>Future.value(List<Map<String,dynamic>>.from(supa.from('profiles').select('id,full_name,email,phone,state,available').eq('role','agent')));", "Future<List<Map<String,dynamic>>> load() async => List<Map<String,dynamic>>.from(await supa.from('profiles').select('id,full_name,email,phone,state,available').eq('role','agent'));" )
s = s.replace("Future<List<Map<String,dynamic>>> load()=>Future.value(List<Map<String,dynamic>>.from(supa.from('products').select('id,name,selling_price,central_stock,active').order('name')));", "Future<List<Map<String,dynamic>>> load() async => List<Map<String,dynamic>>.from(await supa.from('products').select('id,name,selling_price,central_stock,active').order('name'));" )
s = s.replace("Future<List<Map<String,dynamic>>> load()=>Future.value(List<Map<String,dynamic>>.from(supa.from('orders').select('id,order_number,customer_name,customer_phone,delivery_address,city,state,total_amount,payment_method,receipt_generated').eq('status','Delivered').order('created_at',ascending:false)));", "Future<List<Map<String,dynamic>>> load() async => List<Map<String,dynamic>>.from(await supa.from('orders').select('id,order_number,customer_name,customer_phone,delivery_address,city,state,total_amount,payment_method,receipt_generated').eq('status','Delivered').order('created_at',ascending:false));" )

p.write_text(s)
