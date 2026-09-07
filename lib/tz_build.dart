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
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TZ - Temz Store',
        theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: blue), scaffoldBackgroundColor: bg),
        home: const AuthGate(),
      );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool recovery = false;
  @override
  void initState() {
    super.initState();
    db.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.passwordRecovery) setState(() => recovery = true);
      if (data.event == AuthChangeEvent.signedOut) setState(() => recovery = false);
    });
  }
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: db.auth.onAuthStateChange,
        builder: (_, __) {
          if (recovery && db.auth.currentSession != null) return const SetNewPasswordPage();
          if (db.auth.currentSession == null) return const LoginPage();
          return const ProfileGate();
        },
      );
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 90});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Image.asset('assets/temz_logo.jpg', fit: BoxFit.contain),
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
    final e = email.text.trim().toLowerCase();
    if (e.isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your email and password.')));
      return;
    }
    setState(() => busy = true);
    try {
      await db.auth.signInWithPassword(email: e, password: password.text);
    } on AuthException catch (ex) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.message)));
    } catch (ex) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed. Please check your internet connection. $ex')));
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
                    const Logo(size: 145),
                    const SizedBox(height: 16),
                    const Text('TZ', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: navy)),
                    const Text('TEMZ STORE OPERATIONS', style: TextStyle(letterSpacing: 2, color: blue, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('ADMIN / AGENT LOGIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: navy)),
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
                            TextField(controller: email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username], decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                            const SizedBox(height: 14),
                            TextField(controller: password, obscureText: hidden, autofillHints: const [AutofillHints.password], decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility : Icons.visibility_off)))),
                            const SizedBox(height: 20),
                            SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : login, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SIGN IN'))),
                            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())), child: const Text('Forgot Password?'))),
                            SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentRegistrationPage())), icon: const Icon(Icons.person_add_alt_1), label: const Text('REGISTER AS AGENT'))),
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

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController();
  bool busy = false;
  Future<void> send() async {
    final e = email.text.trim().toLowerCase();
    if (e.isEmpty) return;
    setState(() => busy = true);
    try {
      await db.auth.resetPasswordForEmail(e, redirectTo: 'tz://auth-callback/');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset email sent. Check your inbox.')));
    } on AuthException catch (ex) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Forgot Password')),
        body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Column(children: [
          const Logo(size: 120),
          const SizedBox(height: 18),
          const Text('Reset your password', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: navy)),
          const SizedBox(height: 8),
          const Text('Enter your TZ account email and we will send you a secure reset link.', textAlign: TextAlign.center),
          const SizedBox(height: 22),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : send, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SEND RESET LINK'))),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Login')),
        ]))))),
      );
}

class SetNewPasswordPage extends StatefulWidget {
  const SetNewPasswordPage({super.key});
  @override
  State<SetNewPasswordPage> createState() => _SetNewPasswordPageState();
}

class _SetNewPasswordPageState extends State<SetNewPasswordPage> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  Future<void> save() async {
    if (password.text.length < 8 || password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords must match and contain at least 8 characters.')));
      return;
    }
    setState(() => busy = true);
    try {
      await db.auth.updateUser(UserAttributes(password: password.text));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ProfileGate()), (_) => false);
    } on AuthException catch (ex) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Set New Password')),
        body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Column(children: [
          const Logo(size: 120),
          const SizedBox(height: 18),
          const Text('Set New Password', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: navy)),
          const SizedBox(height: 8),
          const Text('Create a new password for your TZ account.', textAlign: TextAlign.center),
          const SizedBox(height: 22),
          TextField(controller: password, obscureText: true, autofillHints: const [AutofillHints.newPassword], decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.lock_outline))),
          const SizedBox(height: 14),
          TextField(controller: confirm, obscureText: true, autofillHints: const [AutofillHints.newPassword], decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.verified_user_outlined))),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : save, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE & CONTINUE'))),
        ]))))),
      );
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
  final stateName = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  Future<void> register() async {
    if (name.text.trim().isEmpty || email.text.trim().isEmpty || phone.text.trim().isEmpty || stateName.text.trim().isEmpty || password.text.length < 8 || password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete all fields and use matching passwords of at least 8 characters.')));
      return;
    }
    setState(() => busy = true);
    try {
      await db.auth.signUp(email: email.text.trim().toLowerCase(), password: password.text, data: {'registration_type': 'agent', 'full_name': name.text.trim(), 'phone': phone.text.trim(), 'state': stateName.text.trim()});
      await db.auth.signOut();
      if (!mounted) return;
      showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Registration submitted'), content: const Text('Your agent registration is awaiting Temz Store admin approval.'), actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('DONE'))]));
    } on AuthException catch (ex) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ex.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Register as Agent')),
        body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
          const Logo(size: 105),
          const SizedBox(height: 8),
          const Text('Agent Registration', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: navy)),
          const SizedBox(height: 6),
          const Text('Submit your details. An admin will approve your access before you can log in.', textAlign: TextAlign.center),
          const SizedBox(height: 18),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 12),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
          const SizedBox(height: 12),
          TextField(controller: stateName, decoration: const InputDecoration(labelText: 'State')),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 12),
          TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password')),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : register, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SUBMIT REGISTRATION'))),
        ])),),
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
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final user = db.auth.currentUser;
      if (user == null) return;
      final row = await db.from('profiles').select('role,full_name,available,agent_approval_status').eq('id', user.id).maybeSingle();
      if (row == null) throw Exception('Account profile not found. Please contact Temz Store admin.');
      final r = '${row['role'] ?? 'agent'}';
      if (r == 'agent' && row['agent_approval_status'] == 'pending') throw Exception('Your agent account is awaiting admin approval.');
      if (r == 'agent' && row['agent_approval_status'] == 'rejected') throw Exception('Your agent registration was rejected. Contact Temz Store admin.');
      if (r == 'agent' && row['available'] != true) throw Exception('Your agent account is currently inactive.');
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
    final isAdmin = widget.role == 'admin';
    final titles = isAdmin ? const ['Admin Dashboard', 'Orders', 'Agents', 'Stock'] : const ['Agent Dashboard', 'My Orders', 'My Stock'];
    final pages = isAdmin ? <Widget>[DashboardPage(role: widget.role, name: widget.name), OrdersPage(role: widget.role), const AgentsPage(), const StockPage()] : <Widget>[DashboardPage(role: widget.role, name: widget.name), OrdersPage(role: widget.role), const StockPage()];
    if (index >= pages.length) index = 0;
    return Scaffold(
      appBar: AppBar(title: Text(titles[index], style: const TextStyle(fontWeight: FontWeight.w900, color: navy)), actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Logo(size: 42))]),
      drawer: Drawer(child: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [const Center(child: Logo(size: 95)), const Center(child: Text('TEMZ STORE', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: navy))), Center(child: Text(widget.role.toUpperCase(), style: const TextStyle(color: blue, fontWeight: FontWeight.w800))), const Divider(height: 30), for (int i = 0; i < pages.length; i++) ListTile(selected: i == index, leading: Icon([Icons.grid_view, Icons.receipt_long, Icons.groups, Icons.inventory_2][i]), title: Text(titles[i]), onTap: () { setState(() => index = i); Navigator.pop(context); }), const Divider(), ListTile(leading: const Icon(Icons.logout), title: const Text('Log out'), onTap: () => db.auth.signOut())]))),
      body: pages[index],
      bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (i) => setState(() => index = i), destinations: [for (int i = 0; i < pages.length; i++) NavigationDestination(icon: Icon([Icons.grid_view, Icons.receipt_long, Icons.groups, Icons.inventory_2][i]), label: titles[i])]),
    );
  }
}

Future<List<Map<String, dynamic>>> loadOrders(String role) async {
  final userId = db.auth.currentUser?.id;
  final query = db.from('orders').select('id,order_number,created_at,customer_name,customer_phone,state,city,delivery_address,assigned_agent_id,status,total_amount');
  final rows = role == 'agent' ? await query.eq('assigned_agent_id', userId!).order('created_at', ascending: false) : await query.order('created_at', ascending: false);
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
  void initState() { super.initState(); future = loadOrders(widget.role); }
  int count(List<Map<String, dynamic>> rows, String status) => rows.where((o) => o['status'] == status).length;
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snap) {
    if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load dashboard. ${snap.error}')));
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    final rows = snap.data!;
    return RefreshIndicator(onRefresh: () async { setState(() => future = loadOrders(widget.role)); await future; }, child: ListView(padding: const EdgeInsets.all(16), children: [
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
      for (final o in rows.take(8)) Card(child: ListTile(title: Text('${o['order_number']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${o['customer_name']} • ${o['status']}'), trailing: Text('₦${o['total_amount'] ?? 0}'))),
    ]));
  });
}

class StatCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;
  const StatCard(this.title, this.value, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(Icons.circle, color: color, size: 15), Text('$value', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: navy)), Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w700))])));
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
    if (snap.hasError) return Center(child: Text('Could not load orders. ${snap.error}'));
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    final rows = snap.data!.where((o) => '${o['order_number']} ${o['customer_name']} ${o['customer_phone']}'.toLowerCase().contains(search.toLowerCase())).toList();
    return Column(children: [Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 8), child: TextField(onChanged: (v) => setState(() => search = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search order, customer or phone'))), Expanded(child: ListView.builder(padding: const EdgeInsets.all(14), itemCount: rows.length, itemBuilder: (context, i) { final o = rows[i]; return Card(child: ListTile(title: Text('${o['order_number']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${o['customer_name']}\n${o['city']}, ${o['state'] ?? ''}'), isThreeLine: true, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetail(order: o, role: widget.role)))); }))]);
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
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('${order['order_number']}')), body: ListView(padding: const EdgeInsets.all(16), children: [Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${order['customer_name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy)), const SizedBox(height: 8), Text('Phone: ${order['customer_phone'] ?? ''}'), Text('State: ${order['state'] ?? ''}'), Text('City: ${order['city'] ?? ''}'), Text('Address: ${order['delivery_address'] ?? ''}'), const SizedBox(height: 8), Text('Status: ${order['status']}', style: const TextStyle(fontWeight: FontWeight.w800)), Text('Total: ₦${order['total_amount'] ?? 0}')]))), if (widget.role == 'agent') Wrap(spacing: 8, runSpacing: 8, children: [FilledButton(onPressed: () => updateStatus('Accepted'), child: const Text('Accept')), OutlinedButton(onPressed: () => updateStatus('Out for Delivery'), child: const Text('Out for Delivery')), OutlinedButton(onPressed: () => updateStatus('Customer Not Available'), child: const Text('Not Available')), OutlinedButton(onPressed: () => updateStatus('Unable to Meet Up'), child: const Text('Unable to Meet Up')), FilledButton(onPressed: () => updateStatus('Delivered'), child: const Text('Delivered'))])])));
}

class AgentsPage extends StatelessWidget {
  const AgentsPage({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(future: db.from('profiles').select('id,full_name,state,available,agent_approval_status').eq('role', 'agent').order('full_name'), builder: (context, snap) { if (snap.hasError) return Center(child: Text('Could not load agents. ${snap.error}')); if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final rows = snap.data!; return ListView(padding: const EdgeInsets.all(14), children: [const Text('Agents', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy)), const SizedBox(height: 10), for (final a in rows) Card(child: ListTile(title: Text('${a['full_name'] ?? 'Agent'}'), subtitle: Text('${a['state'] ?? ''} • ${a['agent_approval_status'] ?? 'approved'} • ${a['available'] == true ? 'Active' : 'Inactive'}')))]); });
}

class StockPage extends StatelessWidget {
  const StockPage({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(future: db.from('products').select('id,name,price,central_stock').order('name'), builder: (context, snap) { if (snap.hasError) return Center(child: Text('Could not load stock. ${snap.error}')); if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final rows = snap.data!; return ListView(padding: const EdgeInsets.all(14), children: [const Text('Central Stock', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy)), const SizedBox(height: 10), for (final p in rows) Card(child: ListTile(title: Text('${p['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Selling price: ₦${p['price'] ?? 0}'), trailing: Text('${p['central_stock'] ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))) ]); });
}
