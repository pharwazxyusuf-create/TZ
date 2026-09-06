import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color navy = Color(0xFF071B3A);
const Color blue = Color(0xFF1264E8);
const Color bg = Color(0xFFF5F8FD);
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        scaffoldBackgroundColor: bg,
      ),
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
        if (db.auth.currentSession == null) {
          return const LoginPage();
        }
        return const ProfileGate();
      },
    );
  }
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
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
      await db.auth.signInWithPassword(
        email: email.text.trim().toLowerCase(),
        password: password.text,
      );
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
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
                  const Text(
                    'TZ',
                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: navy),
                  ),
                  const Text(
                    'TEMZ STORE OPERATIONS',
                    style: TextStyle(letterSpacing: 2, color: blue, fontWeight: FontWeight.w800),
                  ),
                  if (widget.message != null) ...[
                    const SizedBox(height: 14),
                    Text(widget.message!, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 25),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: password,
                            obscureText: hidden,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => hidden = !hidden),
                                icon: Icon(hidden ? Icons.visibility : Icons.visibility_off),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: busy ? null : login,
                              child: busy
                                  ? const CircularProgressIndicator()
                                  : const Text('SIGN IN'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('Temz Store • 09012533620'),
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
      final row = await db
          .from('profiles')
          .select('role,full_name')
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) {
        throw Exception('Account is not activated by Temz Store.');
      }
      if (!mounted) return;
      setState(() {
        role = '${row['role'] ?? 'agent'}';
        name = '${row['full_name'] ?? ''}';
      });
    } catch (e) {
      await db.auth.signOut();
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return LoginPage(message: error);
    if (role == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
    final pages = <Widget>[
      DashboardPage(role: widget.role, name: widget.name),
      OrdersPage(role: widget.role),
      AgentsPage(role: widget.role),
      StockPage(role: widget.role),
    ];
    final titles = ['Dashboard', 'Orders', 'Agents', 'Stock'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index], style: const TextStyle(fontWeight: FontWeight.w900, color: navy)),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Logo(size: 42))],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Center(child: Logo(size: 95)),
              const Center(child: Text('TEMZ STORE', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: navy))),
              Center(child: Text(widget.role.toUpperCase(), style: const TextStyle(color: blue, fontWeight: FontWeight.w800))),
              const Divider(height: 30),
              for (int i = 0; i < titles.length; i++)
                ListTile(
                  selected: i == index,
                  leading: Icon([Icons.dashboard, Icons.receipt_long, Icons.groups, Icons.inventory_2][i]),
                  title: Text(titles[i]),
                  onTap: () {
                    setState(() => index = i);
                    Navigator.pop(context);
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: () => db.auth.signOut(),
              ),
            ],
          ),
        ),
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Agents'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Stock'),
        ],
      ),
    );
  }
}

Future<List<Map<String, dynamic>>> loadOrders(String role) async {
  final base = db.from('orders').select(
    'id,order_number,created_at,customer_name,customer_phone,state,city,delivery_address,assigned_agent_id,status,total_amount',
  );
  final rows = role == 'agent'
      ? await base.eq('assigned_agent_id', db.auth.currentUser!.id).order('created_at', ascending: false)
      : await base.order('created_at', ascending: false);
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
  void initState() {
    super.initState();
    future = loadOrders(widget.role);
  }

  int count(List<Map<String, dynamic>> rows, String status) => rows.where((o) => o['status'] == status).length;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final rows = snapshot.data ?? <Map<String, dynamic>>[];
        return RefreshIndicator(
          onRefresh: () async => setState(() => future = loadOrders(widget.role)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Good day, ${widget.name.isEmpty ? 'Welcome' : widget.name}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy)),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  StatCard('New Orders', count(rows, 'New Order'), blue),
                  StatCard('Awaiting Acceptance', count(rows, 'Awaiting Agent Acceptance'), orange),
                  StatCard('Out for Delivery', count(rows, 'Out for Delivery'), navy),
                  StatCard('Delivered', count(rows, 'Delivered'), green),
                  StatCard('Postponed', count(rows, 'Customer Chose Another Day'), orange),
                  StatCard('Cancelled', count(rows, 'Cancelled'), red),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Recent Orders', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: navy)),
              for (final order in rows.take(8))
                Card(
                  child: ListTile(
                    title: Text('${order['order_number']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${order['customer_name']} • ${order['status']}'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;
  const StatCard(this.title, this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.circle, color: color, size: 14),
            Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: navy)),
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
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
  void initState() {
    super.initState();
    future = loadOrders(widget.role);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final all = snapshot.data ?? <Map<String, dynamic>>[];
        final rows = all.where((o) {
          final text = '${o['order_number']} ${o['customer_name']} ${o['customer_phone']}'.toLowerCase();
          return text.contains(search.toLowerCase());
        }).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                onChanged: (value) => setState(() => search = value),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search order, customer or phone'),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final order = rows[index];
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => OrderDetailPage(order: order, role: widget.role)),
                      ),
                      leading: CircleAvatar(child: Icon(order['status'] == 'Delivered' ? Icons.check : Icons.local_shipping_outlined)),
                      title: Text('${order['order_number']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${order['customer_name']}\n${order['city']}, ${order['state'] ?? ''}'),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class OrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> order;
  final String role;
  const OrderDetailPage({super.key, required this.order, required this.role});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Map<String, dynamic> order;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    order = Map<String, dynamic>.from(widget.order);
  }

  Future<void> updateStatus(String status) async {
    setState(() => busy = true);
    try {
      await db.rpc('tz_agent_update_order', params: {
        'p_order': order['id'],
        'p_status': status,
        'p_scheduled_date': null,
      });
      if (mounted) setState(() => order['status'] = status);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agent = widget.role == 'agent';
    return Scaffold(
      appBar: AppBar(title: Text('${order['order_number']}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${order['customer_name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy)),
                  const SizedBox(height: 8),
                  Text('Phone: ${order['customer_phone'] ?? ''}'),
                  Text('State: ${order['state'] ?? ''}'),
                  Text('City: ${order['city'] ?? ''}'),
                  Text('Address: ${order['delivery_address'] ?? ''}'),
                  const SizedBox(height: 8),
                  Text('Status: ${order['status']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('Total: ₦${order['total_amount'] ?? 0}'),
                ],
              ),
            ),
          ),
          if (agent) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(onPressed: busy ? null : () => updateStatus('Accepted'), child: const Text('Accept')),
                OutlinedButton(onPressed: busy ? null : () => updateStatus('Out for Delivery'), child: const Text('Out for Delivery')),
                OutlinedButton(onPressed: busy ? null : () => updateStatus('Customer Not Available'), child: const Text('Not Available')),
                OutlinedButton(onPressed: busy ? null : () => updateStatus('Unable to Meet Up'), child: const Text('Unable to Meet Up')),
                FilledButton(onPressed: busy ? null : () => updateStatus('Delivered'), child: const Text('Delivered')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class AgentsPage extends StatelessWidget {
  final String role;
  const AgentsPage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: db.from('profiles').select('id,full_name,state,available').eq('role', 'agent').order('full_name'),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final rows = snapshot.data ?? <Map<String, dynamic>>[];
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text(role == 'admin' ? 'Agents' : 'Agent Team', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy)),
            const SizedBox(height: 10),
            for (final agent in rows)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(agent['available'] == true ? Icons.check : Icons.pause)),
                  title: Text('${agent['full_name'] ?? 'Agent'}'),
                  subtitle: Text('${agent['state'] ?? ''} • ${agent['available'] == true ? 'Available' : 'Unavailable'}'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class StockPage extends StatelessWidget {
  final String role;
  const StockPage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: db.from('products').select('id,name,price,central_stock').order('name'),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final rows = snapshot.data ?? <Map<String, dynamic>>[];
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text(role == 'admin' ? 'Central Stock' : 'Available Products', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy)),
            const SizedBox(height: 10),
            for (final product in rows)
              Card(
                child: ListTile(
                  title: Text('${product['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Selling price: ₦${product['price'] ?? 0}'),
                  trailing: Text('${product['central_stock'] ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        );
      },
    );
  }
}
