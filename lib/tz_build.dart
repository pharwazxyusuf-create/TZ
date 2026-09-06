import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color navy = Color(0xFF071B3A);
const Color blue = Color(0xFF1264E8);
const Color bg = Color(0xFFF5F8FD);
const Color green = Color(0xFF159A63);
const Color red = Color(0xFFD92D4F);
const Color orange = Color(0xFFE58A00);
const String supabaseUrl = 'https://xztnrpfrrqfxqfmboruc.supabase.co';
const String supabaseKey = 'sb_publishable_fFB3uYqNtygqBB_ARmKSdQ_qHU5SdTL';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const TZApp());
}

final SupabaseClient db = Supabase.instance.client;

class TZApp extends StatelessWidget {
  const TZApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TZ - Temz Store',
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: blue), scaffoldBackgroundColor: bg),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: db.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (db.auth.currentSession == null) return const LoginPage();
        return const ProfileGate();
      },
    );
  }
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 90});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Image.asset('assets/temz_logo.jpg', fit: BoxFit.contain),
    );
  }
}

class LoginPage extends StatefulWidget {
  final String? message;
  const LoginPage({super.key, this.message});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool hidden = true;

  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) return;
    setState(() => busy = true);
    try {
      await db.auth.signInWithPassword(email: email.text.trim().toLowerCase(), password: password.text);
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  const Logo(size: 145),
                  const SizedBox(height: 18),
                  const Text('TZ', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: navy)),
                  const Text('TEMZ STORE OPERATIONS', style: TextStyle(letterSpacing: 2, color: blue, fontWeight: FontWeight.w800)),
                  if (widget.message != null) ...[
                    const SizedBox(height: 14),
                    Text(widget.message!, textAlign: TextAlign.center, style: const TextStyle(color: red, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 25),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                          const SizedBox(height: 14),
                          TextField(controller: password, obscureText: hidden, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility : Icons.visibility_off)))),
                          const SizedBox(height: 20),
                          SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : login, child: busy ? const CircularProgressIndicator() : const Text('SIGN IN'))),
                          const SizedBox(height: 12),
                          const Text('Temz Store • 09012533620', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  String? role;
  String name = '';
  String? error;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final user = db.auth.currentUser;
      if (user == null) return;
      final row = await db.from('profiles').select('role,full_name').eq('id', user.id).maybeSingle();
      if (row == null) throw Exception('Your account has not been activated by a Temz Store administrator.');
      if (!mounted) return;
      setState(() {
        role = '${row['role'] ?? 'agent'}';
        name = '${row['full_name'] ?? ''}';
      });
    } catch (e) {
      await db.auth.signOut();
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return LoginPage(message: error);
    if (role == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return HomeShell(role: role!, name: name);
  }
}

class HomeShell extends StatefulWidget {
  final String role;
  final String name;
  const HomeShell({super.key, required this.role, required this.name});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(role: widget.role),
      OrdersPage(role: widget.role),
      if (widget.role == 'admin') const AgentsPage(),
      const StockPage(),
    ];
    final labels = widget.role == 'admin' ? const ['Home', 'Orders', 'Agents', 'Stock'] : const ['Home', 'Orders', 'Stock'];
    if (index >= pages.length) index = 0;
    return Scaffold(
      appBar: AppBar(title: Text(labels[index], style: const TextStyle(fontWeight: FontWeight.w900, color: navy)), actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Logo(size: 42))]),
      drawer: Drawer(child: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [const Center(child: Logo(size: 90)), const Center(child: Text('TEMZ STORE', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: navy))), Center(child: Text(widget.role.toUpperCase(), style: const TextStyle(color: blue, fontWeight: FontWeight.w800))), const Divider(height: 30), for (int i = 0; i < labels.length; i++) ListTile(selected: i == index, leading: Icon([Icons.dashboard_outlined, Icons.receipt_long, Icons.groups, Icons.inventory_2][i]), title: Text(labels[i]), onTap: () { setState(() => index = i); Navigator.pop(context); }), const Divider(), ListTile(leading: const Icon(Icons.logout), title: const Text('Log out'), onTap: () => db.auth.signOut())]))),
      body: pages[index],
      bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (i) => setState(() => index = i), destinations: [for (final label in labels) NavigationDestination(icon: Icon(label == 'Home' ? Icons.dashboard_outlined : label == 'Orders' ? Icons.receipt_long : label == 'Agents' ? Icons.groups : Icons.inventory_2), label: label)]),
    );
  }
}

Future<List<Map<String, dynamic>>> loadOrders(String role) async {
  final user = db.auth.currentUser;
  final query = db.from('orders').select('id,order_number,created_at,customer_name,customer_phone,state,city,delivery_address,status,assigned_agent_id,total_amount,amount_charged,amount_remitted,payment_method');
  final rows = role == 'agent' && user != null
      ? await query.eq('assigned_agent_id', user.id).order('created_at', ascending: false)
      : await query.order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows);
}

class Dashboard extends StatefulWidget {
  final String role;
  const Dashboard({super.key, required this.role});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() { super.initState(); future = loadOrders(widget.role); }
  int count(List<Map<String, dynamic>> rows, String status) => rows.where((r) => r['status'] == status).length;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snap.data!;
      final cards = [
        ['New Orders', count(rows, 'New Order'), blue],
        ['Awaiting Acceptance', count(rows, 'Awaiting Agent Acceptance'), orange],
        ['Out for Delivery', count(rows, 'Out for Delivery'), navy],
        ['Delivered', count(rows, 'Delivered'), green],
        ['Postponed', count(rows, 'Customer Chose Another Day'), orange],
        ['Cancelled', count(rows, 'Cancelled'), red],
      ];
      return RefreshIndicator(onRefresh: () async => setState(() => future = loadOrders(widget.role)), child: ListView(padding: const EdgeInsets.all(16), children: [Text(widget.role == 'admin' ? 'Good day, Admin' : 'Agent dashboard', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: navy)), const SizedBox(height: 20), GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.45, children: [for (final c in cards) StatCard('${c[0]}', c[1] as int, c[2] as Color)]), const SizedBox(height: 22), const Text('Recent orders', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: navy)), for (final order in rows.take(8)) Card(child: ListTile(title: Text('${order['order_number']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${order['customer_name']} • ${order['status']}'), trailing: Text('₦${order['total_amount'] ?? 0}')))]));
    });
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;
  const StatCard(this.title, this.value, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(Icons.circle, color: color, size: 14), Text('$value', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: navy)), Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))])));
}

class OrdersPage extends StatefulWidget {
  final String role;
  const OrdersPage({super.key, required this.role});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late Future<List<Map<String, dynamic>>> future;
  String search = '';
  @override
  void initState() { super.initState(); future = loadOrders(widget.role); }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snap) {
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    final rows = snap.data!.where((o) => '${o['order_number']} ${o['customer_name']} ${o['customer_phone']}'.toLowerCase().contains(search.toLowerCase())).toList();
    return Column(children: [Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 8), child: TextField(onChanged: (v) => setState(() => search = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search order, customer or phone'))), Expanded(child: ListView.builder(padding: const EdgeInsets.all(14), itemCount: rows.length, itemBuilder: (context, i) { final o = rows[i]; return Card(child: ListTile(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetail(order: o, role: widget.role))), leading: CircleAvatar(child: Icon(o['status'] == 'Delivered' ? Icons.check : Icons.local_shipping_outlined)), title: Text('${o['order_number']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${o['customer_name']}\n${o['city']}, ${o['state'] ?? o['state']}'), isThreeLine: true); })))]);
  });
}

class OrderDetail extends StatefulWidget {
  final Map<String, dynamic> order;
  final String role;
  const OrderDetail({super.key, required this.order, required this.role});
  @override
  State<OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<OrderDetail> {
  late Map<String, dynamic> order;
  @override
  void initState() { super.initState(); order = Map<String, dynamic>.from(widget.order); }

  Future<void> updateStatus(String status) async {
    try {
      await db.rpc('tz_agent_update_order', params: {'p_order': order['id'], 'p_status': status, 'p_scheduled_date': null});
      if (mounted) setState(() => order['status'] = status);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAgent = widget.role == 'agent';
    return Scaffold(appBar: AppBar(title: Text('${order['order_number']}')), body: ListView(padding: const EdgeInsets.all(16), children: [Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${order['customer_name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy)), const SizedBox(height: 8), Text('Phone: ${order['customer_phone'] ?? ''}'), Text('State: ${order['state'] ?? ''}'), Text('City: ${order['city'] ?? ''}'), Text('Address: ${order['delivery_address'] ?? ''}'), const SizedBox(height: 8), Text('Status: ${order['status']}', style: const TextStyle(fontWeight: FontWeight.w800)), Text('Total: ₦${order['total_amount'] ?? 0}')]))), const SizedBox(height: 14), if (isAgent) Wrap(spacing: 8, runSpacing: 8, children: [FilledButton(onPressed: () => updateStatus('Accepted'), child: const Text('Accept')), OutlinedButton(onPressed: () => updateStatus('Out for Delivery'), child: const Text('Out for Delivery')), OutlinedButton(onPressed: () => updateStatus('Customer Not Available'), child: const Text('Not Available')), OutlinedButton(onPressed: () => updateStatus('Unable to Meet Up'), child: const Text('Unable to Meet Up')), FilledButton(onPressed: () => updateStatus('Delivered'), child: const Text('Delivered'))]), if (!isAgent) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Admin can assign and monitor this order from the operations dashboard.'))]));
  }
}

class AgentsPage extends StatelessWidget {
  const AgentsPage({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(future: db.from('profiles').select('id,full_name,state,available').eq('role', 'agent').order('full_name'), builder: (context, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final rows = snap.data!; return ListView(padding: const EdgeInsets.all(14), children: [const Text('Agents', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy)), const SizedBox(height: 10), for (final a in rows) Card(child: ListTile(leading: CircleAvatar(child: Icon(a['available'] == true ? Icons.check : Icons.pause)), title: Text('${a['full_name'] ?? 'Agent'}'), subtitle: Text('${a['state'] ?? ''} • ${a['available'] == true ? 'Available' : 'Unavailable'}')))]); });
}

class StockPage extends StatelessWidget {
  const StockPage({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(future: db.from('products').select('id,name,price,central_stock').order('name'), builder: (context, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final rows = snap.data!; return ListView(padding: const EdgeInsets.all(14), children: [const Text('Central Stock', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy)), const SizedBox(height: 10), for (final p in rows) Card(child: ListTile(title: Text('${p['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Selling price: ₦${p['price'] ?? 0}'), trailing: Text('${p['central_stock'] ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))) ]); });
}
