from pathlib import Path

# Final parser-safe TZ source. This intentionally replaces the previous generated
# source instead of stacking text patches on top of each other.
source = Path('lib/tz_build.dart')
source.write_text(r'''import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'password_pages.dart';

const Color navy = Color(0xFF071B3A);
const Color blue = Color(0xFF1264E8);
const Color bg = Color(0xFFF5F8FD);
const Color green = Color(0xFF159A63);
const Color red = Color(0xFFD92D4F);
const Color orange = Color(0xFFE58A00);
const String supabaseUrl = 'https://xztnrpfrrqfxqfmboruc.supabase.co';
const String supabaseKey = 'sb_publishable_fFB3uYqNtygqBB_ARmKSdQ_qHU5SdTL';
const String authRedirect = 'https://temz.ng/tz-auth/';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        scaffoldBackgroundColor: bg,
      ),
      home: const AuthGate(),
    );
  }
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 90});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset('assets/temz_logo_clean.svg'),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: db.auth.onAuthStateChange,
        builder: (_, __) => db.auth.currentSession == null
            ? const LoginPage()
            : const ProfileGate(),
      );
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
      await db.auth.signInWithPassword(
        email: email.text.trim().toLowerCase(),
        password: password.text,
      );
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to connect to Temz Store. Check your internet connection and try again.')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  children: [
                    const Logo(size: 150),
                    const SizedBox(height: 14),
                    const Text('TZ', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: navy)),
                    const Text('TEMZ STORE OPERATIONS', style: TextStyle(color: blue, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    if (widget.message != null) ...[
                      const SizedBox(height: 14),
                      Text(widget.message!, textAlign: TextAlign.center, style: const TextStyle(color: red, fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 22),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                            const SizedBox(height: 14),
                            TextField(controller: password, obscureText: hidden, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility : Icons.visibility_off)))),
                            const SizedBox(height: 18),
                            SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : login, child: busy ? const CircularProgressIndicator() : const Text('SIGN IN'))),
                            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())), child: const Text('Forgot Password?'))),
                            TextButton(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentRegistrationPage())), child: const Text('REGISTER AS AGENT')),
                            const SizedBox(height: 6),
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
    load();
  }

  Future<void> load() async {
    try {
      final user = db.auth.currentUser;
      if (user == null) return;
      final row = await db.from('profiles').select('role,full_name,available,agent_approval_status').eq('id', user.id).maybeSingle();
      if (row == null) throw Exception('Your account is not registered in TZ.');
      final r = '${row['role'] ?? 'agent'}';
      final approval = '${row['agent_approval_status'] ?? 'approved'}';
      if (r == 'agent' && approval == 'pending') throw Exception('Your agent registration is awaiting admin approval.');
      if (r == 'agent' && approval == 'rejected') throw Exception('Your agent registration was not approved. Please contact Temz Store.');
      if (r == 'agent' && row['available'] == false) throw Exception('Your agent account is currently inactive.');
      if (!mounted) return;
      setState(() { role = r; name = '${row['full_name'] ?? ''}'; });
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
    final admin = widget.role == 'admin';
    final titles = admin ? const ['Dashboard', 'Orders', 'Agents', 'Stock'] : const ['Dashboard', 'Orders', 'My Stock'];
    final pages = admin
        ? <Widget>[DashboardPage(role: widget.role, name: widget.name), OrdersPage(role: widget.role), const AgentsPage(), StockPage(agentId: null)]
        : <Widget>[DashboardPage(role: widget.role, name: widget.name), OrdersPage(role: widget.role), StockPage(agentId: db.auth.currentUser?.id)];
    final icons = admin ? const [Icons.grid_view, Icons.receipt_long, Icons.groups, Icons.inventory_2] : const [Icons.grid_view, Icons.receipt_long, Icons.inventory_2];
    if (index >= pages.length) index = 0;
    return Scaffold(
      appBar: AppBar(title: Text(titles[index], style: const TextStyle(fontWeight: FontWeight.w900, color: navy)), actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Logo(size: 42))]),
      drawer: Drawer(child: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        const Center(child: Logo(size: 105)),
        const SizedBox(height: 8),
        const Center(child: Text('TEMZ STORE', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: navy))),
        Center(child: Text(widget.role.toUpperCase(), style: const TextStyle(color: blue, fontWeight: FontWeight.w800))),
        const Divider(height: 30),
        for (int i = 0; i < titles.length; i++) ListTile(selected: i == index, leading: Icon(icons[i]), title: Text(titles[i]), onTap: () { setState(() => index = i); Navigator.pop(context); }),
        const Divider(),
        ListTile(leading: const Icon(Icons.lock_reset), title: const Text('Change password'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage()))),
        ListTile(leading: const Icon(Icons.logout), title: const Text('Log out'), onTap: () => db.auth.signOut()),
      ]))),
      body: pages[index],
      bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (i) => setState(() => index = i), destinations: [for (int i = 0; i < titles.length; i++) NavigationDestination(icon: Icon(icons[i]), label: titles[i])]),
    );
  }
}

Future<List<Map<String, dynamic>>> getOrders(String role) async {
  final q = role == 'agent'
      ? db.from('orders').select('id,order_number,customer_name,customer_phone,state,city,delivery_address,status,total_amount,assigned_agent_id').eq('assigned_agent_id', db.auth.currentUser!.id)
      : db.from('orders').select('id,order_number,customer_name,customer_phone,state,city,delivery_address,status,total_amount,assigned_agent_id');
  final rows = await q.order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows);
}

class DashboardPage extends StatefulWidget {
  final String role;
  final String name;
  const DashboardPage({super.key, required this.role, required this.name});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() { super.initState(); future = getOrders(widget.role); }
  int count(List<Map<String, dynamic>> rows, String status) => rows.where((x) => x['status'] == status).length;
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('Good day, ${widget.name.isEmpty ? 'Welcome' : widget.name}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy)),
            const SizedBox(height: 18),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, children: [
              StatCard('New Orders', count(rows, 'New Order'), blue),
              StatCard('Awaiting Acceptance', count(rows, 'Awaiting Agent Acceptance'), orange),
              StatCard('Out for Delivery', count(rows, 'Out for Delivery'), navy),
              StatCard('Delivered', count(rows, 'Delivered'), green),
              StatCard('Postponed', count(rows, 'Customer Chose Another Day'), orange),
              StatCard('Cancelled', count(rows, 'Cancelled'), red),
            ]),
            const SizedBox(height: 20),
            const Text('Recent Orders', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: navy)),
            for (final o in rows.take(8)) Card(child: ListTile(title: Text('${o['order_number']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${o['customer_name']} • ${o['status']}'))),
          ]);
        },
      );
}

class StatCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;
  const StatCard(this.title, this.value, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(Icons.circle, color: color, size: 14), Text('$value', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: navy)), Text(title, style: const TextStyle(fontWeight: FontWeight.w700))])));
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
  void initState() { super.initState(); future = getOrders(widget.role); }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!.where((o) => '${o['order_number']} ${o['customer_name']} ${o['customer_phone']}'.toLowerCase().contains(search.toLowerCase())).toList();
          return Column(children: [
            Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => search = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search order, customer or phone'))),
            Expanded(child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: rows.length, itemBuilder: (_, i) {
              final o = rows[i];
              return Card(child: ListTile(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetail(order: o, role: widget.role))), title: Text('${o['order_number']}'), subtitle: Text('${o['customer_name']}\n${o['city']}, ${o['state'] ?? ''}'), isThreeLine: true, trailing: Text('${o['status']}')));
            }))
          ]);
        },
      );
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
  Future<void> setStatus(String status) async {
    try {
      await db.rpc('tz_agent_update_order', params: {'p_order': order['id'], 'p_status': status, 'p_scheduled_date': null});
      if (mounted) setState(() => order['status'] = status);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }
  @override
  Widget build(BuildContext context) {
    final agent = widget.role == 'agent';
    return Scaffold(appBar: AppBar(title: Text('${order['order_number']}')), body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${order['customer_name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 8),
        Text('Phone: ${order['customer_phone'] ?? ''}'),
        Text('Address: ${order['delivery_address'] ?? ''}'),
        Text('Location: ${order['city'] ?? ''}, ${order['state'] ?? ''}'),
        Text('Status: ${order['status'] ?? ''}'),
      ]))),
      if (agent) ...[
        const SizedBox(height: 12),
        FilledButton(onPressed: () => setStatus('Accepted'), child: const Text('ACCEPT')),
        OutlinedButton(onPressed: () => setStatus('Out for Delivery'), child: const Text('OUT FOR DELIVERY')),
        OutlinedButton(onPressed: () => setStatus('Customer Not Available'), child: const Text('CUSTOMER NOT AVAILABLE')),
        OutlinedButton(onPressed: () => setStatus('Unable to Meet Up'), child: const Text('UNABLE TO MEET UP')),
        FilledButton(onPressed: () => setStatus('Delivered'), child: const Text('DELIVERED')),
        OutlinedButton(onPressed: () => setStatus('Cancelled'), child: const Text('CANCELLED')),
      ]
    ]));
  }
}

class AgentsPage extends StatefulWidget {
  const AgentsPage({super.key});
  @override
  State<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends State<AgentsPage> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() { super.initState(); future = load(); }
  Future<List<Map<String, dynamic>>> load() async {
    final rows = await db.from('profiles').select('id,full_name,email,phone,state,available,agent_approval_status').eq('role', 'agent').order('full_name');
    return List<Map<String, dynamic>>.from(rows);
  }
  Future<void> approval(String id, String status) async { await db.rpc('tz_set_agent_approval', params: {'p_agent': id, 'p_status': status}); setState(() => future = load()); }
  Future<void> active(String id, bool value) async { await db.rpc('tz_set_agent_active', params: {'p_agent': id, 'p_active': value}); setState(() => future = load()); }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (_, snap) {
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(14), children: [
      const Text('Agents', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy)),
      const SizedBox(height: 8),
      const Text('Agents register themselves. Approve them here.'),
      const SizedBox(height: 12),
      for (final a in snap.data!) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${a['full_name'] ?? 'Unnamed agent'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        Text('${a['email'] ?? ''}'),
        Text('${a['phone'] ?? ''} • ${a['state'] ?? ''}'),
        Text('Status: ${a['agent_approval_status'] ?? 'approved'}'),
        const SizedBox(height: 8),
        if (a['agent_approval_status'] == 'pending') Row(children: [
          Expanded(child: FilledButton(onPressed: () => approval('${a['id']}', 'approved'), child: const Text('APPROVE'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: () => approval('${a['id']}', 'rejected'), child: const Text('REJECT'))),
        ]),
        if (a['agent_approval_status'] == 'approved') SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => active('${a['id']}', a['available'] != true), child: Text(a['available'] == true ? 'REMOVE AGENT' : 'RESTORE AGENT'))),
      ])))
    ]);
  });
}

class AgentRegistrationPage extends StatefulWidget {
  const AgentRegistrationPage({super.key});
  @override
  State<AgentRegistrationPage> createState() => _AgentRegistrationPageState();
}

class _AgentRegistrationPageState extends State<AgentRegistrationPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final state = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;

  Future<void> register() async {
    final n = name.text.trim();
    final e = email.text.trim().toLowerCase();
    if (n.isEmpty || !e.contains('@') || phone.text.trim().isEmpty || state.text.trim().isEmpty || password.text.length < 8 || password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete all fields. Passwords must match and contain at least 8 characters.')));
      return;
    }
    setState(() => busy = true);
    try {
      await db.auth.signUp(email: e, password: password.text, data: {'full_name': n, 'phone': phone.text.trim(), 'state': state.text.trim(), 'registration_type': 'agent'});
      await db.auth.signOut();
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Registration submitted'), content: const Text('Your registration has been submitted. A Temz Store administrator must approve it before you can sign in.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Register as Agent')), body: ListView(padding: const EdgeInsets.all(22), children: [
    const Logo(size: 105),
    const SizedBox(height: 12),
    const Text('Join Temz Store as an Agent', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: navy)),
    const SizedBox(height: 8),
    const Text('Submit your details. An administrator will review and approve your registration.'),
    const SizedBox(height: 20),
    TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
    const SizedBox(height: 12),
    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
    const SizedBox(height: 12),
    TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
    const SizedBox(height: 12),
    TextField(controller: state, decoration: const InputDecoration(labelText: 'State')),
    const SizedBox(height: 12),
    TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Create password (8+ characters)')),
    const SizedBox(height: 12),
    TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password')),
    const SizedBox(height: 20),
    SizedBox(height: 52, child: FilledButton(onPressed: busy ? null : register, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SUBMIT REGISTRATION'))),
  ]));
}

class StockPage extends StatelessWidget {
  final String? agentId;
  const StockPage({super.key, required this.agentId});
  @override
  Widget build(BuildContext context) {
    final query = agentId == null ? db.from('products').select('id,name,selling_price,central_stock') : db.from('agent_stock').select('quantity,products(name,selling_price)').eq('agent_id', agentId!);
    return FutureBuilder<List<Map<String, dynamic>>>(future: query.then((v) => List<Map<String, dynamic>>.from(v)), builder: (_, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snap.data!;
      return ListView(padding: const EdgeInsets.all(14), children: [
        Text(agentId == null ? 'Central Stock' : 'My Stock', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 10),
        for (final p in rows) Card(child: ListTile(title: Text('${agentId == null ? p['name'] : (p['products']?['name'] ?? 'Product')}'), subtitle: Text(agentId == null ? 'Selling price: ₦${p['selling_price'] ?? 0}' : 'In care: ${p['quantity'] ?? 0}'), trailing: Text('${agentId == null ? p['central_stock'] ?? 0 : p['quantity'] ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))))
      ]);
    });
  }
}
''', encoding='utf-8')
print('Replaced generated TZ source with a clean parser-safe release source.')
