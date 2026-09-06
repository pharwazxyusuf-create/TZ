import 'package:flutter/material.dart';

// TZ — Temz Store Operations
// Full functional front-end foundation. Business rules are kept in one place so
// the cloud service can enforce the same rules when connected.

const navy = Color(0xFF071B3A);
const blue = Color(0xFF1264E8);
const cyan = Color(0xFF00A8E8);
const bg = Color(0xFFF5F8FD);
const green = Color(0xFF159A63);
const red = Color(0xFFD92D4F);
const orange = Color(0xFFE58A00);
const phone = '09012533620';
const admins = <String>{
  'pharwazxyusuf@gmail.com',
  'mytemzbusiness@gmail.com',
  'omolaratemilade567@gmail.com',
};
const adminTestPassword = 'TZ2026!';
const agentTestEmail = 'agent@temz.ng';
const agentTestPassword = 'Agent2026!';

const deliveryStatuses = <String>[
  'New Order',
  'Awaiting Agent Acceptance',
  'Accepted',
  'Out for Delivery',
  'Customer Not Available',
  'Unable to Meet Up',
  'Customer Chose Another Day',
  'Delivered',
  'Cancelled',
];

class Product {
  Product(this.name, this.price, this.centralStock);
  String name;
  double price;
  int centralStock;
}

class Agent {
  Agent(this.name, this.phone, this.state, {this.available = true});
  String name;
  String phone;
  String state;
  bool available;
  final Map<String, int> stock = {};
}

class OrderItem {
  OrderItem(this.product, this.qty);
  String product;
  int qty;
}

class Order {
  Order({
    required this.id,
    required this.createdAt,
    required this.customer,
    required this.phone,
    this.email = '',
    required this.state,
    required this.city,
    required this.address,
    required this.items,
    required this.total,
    this.status = 'New Order',
    this.agent = '',
    this.scheduledDate = '',
    this.amountCharged = 0,
    this.amountRemitted = 0,
    this.extraCharge = 0,
    this.extraReason = '',
    this.paymentMethod = '',
    this.receiptGenerated = false,
  });
  String id;
  DateTime createdAt;
  String customer, phone, email, state, city, address;
  List<OrderItem> items;
  double total;
  String status, agent, scheduledDate;
  double amountCharged, amountRemitted, extraCharge;
  String extraReason, paymentMethod;
  bool receiptGenerated;

  bool get finalOutcome => const [
        'Delivered',
        'Customer Not Available',
        'Unable to Meet Up',
        'Customer Chose Another Day',
        'Cancelled',
      ].contains(status);
}

final products = <Product>[
  Product('Motion Sensor Light', 18000, 120),
  Product('Electronic Posture Corrector', 22000, 75),
  Product('Anti-Snoring Device', 12000, 90),
  Product('Creative 3D Visualization Lamp', 20000, 60),
];

final agents = <Agent>[
  Agent('Demo Agent', '08000000000', 'Lagos')
    ..stock.addAll({'Motion Sensor Light': 10, 'Electronic Posture Corrector': 5, 'Anti-Snoring Device': 5, 'Creative 3D Visualization Lamp': 2}),
];

final orders = <Order>[
  Order(
    id: 'TZ-000124', createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    customer: 'Aisha Bello', phone: '08011112222', state: 'Lagos', city: 'Ikeja',
    address: '12 Allen Avenue, Ikeja',
    items: [OrderItem('Motion Sensor Light', 2)], total: 36000,
    status: 'Out for Delivery', agent: 'Demo Agent',
  ),
  Order(
    id: 'TZ-000123', createdAt: DateTime.now().subtract(const Duration(days: 1)),
    customer: 'Yusuf Ade', phone: '08033334444', state: 'Ogun', city: 'Abeokuta',
    address: '15 Oke-Igbein, Abeokuta',
    items: [OrderItem('Electronic Posture Corrector', 1), OrderItem('Anti-Snoring Device', 1)],
    total: 34000, status: 'Customer Chose Another Day', agent: 'Demo Agent', scheduledDate: '2026-09-08',
  ),
];

void main() => runApp(const TZApp());

class TZApp extends StatelessWidget {
  const TZApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TZ • Temz Store',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: bg,
          colorScheme: ColorScheme.fromSeed(seedColor: blue),
          fontFamily: 'Arial',
          appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: navy, elevation: 0),
          cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.only(bottom: 12)),
          inputDecorationTheme: InputDecorationTheme(
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: blue, width: 1.5)),
          ),
        ),
        home: const LoginPage(),
      );
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 84});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size, padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * .2), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 18)]),
        child: Image.asset('assets/temz_logo.jpg', fit: BoxFit.contain),
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginState();
}
class _LoginState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool hidden = true;
  void signIn() {
    final e = email.text.trim().toLowerCase();
    final p = password.text;
    if (admins.contains(e) && p == adminTestPassword) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Home(role: 'Admin')));
    } else if (e == agentTestEmail && p == agentTestPassword) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Home(role: 'Agent')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid email or password')));
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(children: [
            const Logo(size: 165), const SizedBox(height: 18),
            const Text('TZ', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: navy)),
            const Text('TEMZ STORE OPERATIONS', style: TextStyle(letterSpacing: 2, color: blue, fontWeight: FontWeight.w800)),
            const SizedBox(height: 30),
            Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline))),
              const SizedBox(height: 14),
              TextField(controller: password, obscureText: hidden, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility : Icons.visibility_off)))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 52, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: navy), onPressed: signIn, child: const Text('SIGN IN'))),
              const SizedBox(height: 12), const Text('Temz Store • 09012533620', style: TextStyle(color: Colors.grey)),
            ]))),
          ]),
        ))));
}

class Home extends StatefulWidget {
  final String role;
  const Home({super.key, required this.role});
  @override State<Home> createState() => _HomeState();
}
class _HomeState extends State<Home> {
  int tab = 0;
  final labels = const ['Dashboard', 'Orders', 'Agents', 'Stock', 'Receipts', 'Settings'];
  void refresh() => setState(() {});
  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(role: widget.role), OrdersPage(role: widget.role, onChanged: refresh),
      AgentsPage(onChanged: refresh), const StockPage(), const ReceiptsPage(),
      SettingsPage(role: widget.role, onChanged: refresh),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(labels[tab], style: const TextStyle(fontWeight: FontWeight.w900)), actions: const [Padding(padding: EdgeInsets.only(right: 14), child: Logo(size: 42))]),
      body: pages[tab],
      drawer: Drawer(child: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        const Center(child: Logo(size: 100)), const SizedBox(height: 8),
        const Center(child: Text('TEMZ STORE', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: navy))),
        Center(child: Text(widget.role, style: const TextStyle(color: blue, fontWeight: FontWeight.w700))), const Divider(height: 30),
        ...List.generate(labels.length, (i) => ListTile(selected: i == tab, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), leading: Icon([Icons.grid_view_rounded, Icons.receipt_long_outlined, Icons.groups_outlined, Icons.inventory_2_outlined, Icons.request_quote_outlined, Icons.settings_outlined][i]), title: Text(labels[i]), onTap: () { setState(() => tab = i); Navigator.pop(context); })),
        const Divider(), ListTile(leading: const Icon(Icons.logout), title: const Text('Log out'), onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false)),
      ]))),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
        NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Agents'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Stock'),
        NavigationDestination(icon: Icon(Icons.request_quote_outlined), label: 'Receipts'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
      ]),
    );
  }
}

class Dashboard extends StatelessWidget {
  final String role;
  const Dashboard({super.key, required this.role});
  int count(String s) => orders.where((o) => o.status == s).length;
  @override
  Widget build(BuildContext context) {
    final awaiting = orders.where((o) => o.status == 'Awaiting Agent Acceptance').length;
    final remittance = orders.where((o) => o.status == 'Delivered' && o.amountRemitted < o.amountCharged).length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Good day, $role', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: navy)),
      Text('Everything important, at a glance.', style: TextStyle(color: Colors.grey.shade600)), const SizedBox(height: 20),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.45, children: [
        Stat('New Orders', count('New Order'), Icons.bolt, blue), Stat('Awaiting Acceptance', awaiting, Icons.hourglass_top, orange),
        Stat('Out for Delivery', count('Out for Delivery'), Icons.local_shipping_outlined, navy), Stat('Delivered', count('Delivered'), Icons.check_circle_outline, green),
        Stat('Postponed', count('Customer Chose Another Day'), Icons.event_repeat, orange), Stat('Cancelled', count('Cancelled'), Icons.cancel_outlined, red),
        Stat('Awaiting Remittance', remittance, Icons.payments_outlined, Colors.purple),
      ]),
      const SizedBox(height: 24), const Text('Recent orders', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: navy)), const SizedBox(height: 8),
      ...orders.take(8).map((o) => Card(child: ListTile(leading: CircleAvatar(backgroundColor: blue.withOpacity(.1), child: const Icon(Icons.receipt_long, color: blue)), title: Text(o.id, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${o.customer} • ${o.status}'), trailing: Text('₦${o.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)))),
    ]);
  }
}
class Stat extends StatelessWidget {
  final String title; final int number; final IconData icon; final Color color;
  const Stat(this.title, this.number, this.icon, this.color, {super.key});
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: color), Text('$number', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: navy)), Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w700))])));
}

class OrdersPage extends StatefulWidget {
  final String role; final VoidCallback onChanged;
  const OrdersPage({super.key, required this.role, required this.onChanged});
  @override State<OrdersPage> createState() => _OrdersPageState();
}
class _OrdersPageState extends State<OrdersPage> {
  String filter = 'All'; final search = TextEditingController();
  @override Widget build(BuildContext context) {
    final list = orders.where((o) => (filter == 'All' || o.status == filter) && '${o.id} ${o.customer} ${o.phone} ${o.agent} ${o.city}'.toLowerCase().contains(search.text.toLowerCase())).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), child: TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Search order, customer, phone or agent', prefixIcon: Icon(Icons.search)))),
      SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: ['All', ...deliveryStatuses].map((s) => Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(s, style: const TextStyle(fontSize: 10)), selected: filter == s, onSelected: (_) => setState(() => filter = s))).toList())),
      Expanded(child: ListView(padding: const EdgeInsets.all(14), children: list.map((o) => Card(child: ListTile(onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(order: o, role: widget.role))); setState(() {}); widget.onChanged(); }, leading: StatusDot(o.status), title: Text(o.id, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${o.customer}\n${o.city}, ${o.state} • ${o.agent.isEmpty ? 'Unassigned' : o.agent}'), isThreeLine: true, trailing: const Icon(Icons.chevron_right))).toList())),
    ],);
  }
}
class StatusDot extends StatelessWidget {
  final String status; const StatusDot(this.status, {super.key});
  @override Widget build(BuildContext context) { Color c = blue; if (status == 'Delivered') c = green; if (status == 'Cancelled') c = red; if (status.contains('Another') || status.contains('Unable') || status.contains('Not Available')) c = orange; return CircleAvatar(radius: 17, backgroundColor: c.withOpacity(.1), child: Icon(status == 'Delivered' ? Icons.check : Icons.local_shipping_outlined, size: 17, color: c)); }
}

class OrderDetailPage extends StatefulWidget {
  final Order order; final String role;
  const OrderDetailPage({super.key, required this.order, required this.role});
  @override State<OrderDetailPage> createState() => _OrderDetailState();
}
class _OrderDetailState extends State<OrderDetailPage> {
  Order get o => widget.order;
  void setStatus(String s) { setState(() => o.status = s); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(o.id, style: const TextStyle(fontWeight: FontWeight.w900))),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(o.customer, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: navy))), StatusPill(o.status)]),
        const SizedBox(height: 7), Text(o.phone, style: const TextStyle(color: blue, fontWeight: FontWeight.w700)), if (o.email.isNotEmpty) Text(o.email), const SizedBox(height: 14),
        const Text('Delivery address', style: TextStyle(fontWeight: FontWeight.w800)), Text('${o.address}\n${o.city}, ${o.state}'), const SizedBox(height: 12),
        Text('Assigned agent: ${o.agent.isEmpty ? 'Unassigned' : o.agent}', style: const TextStyle(fontWeight: FontWeight.w700)), if (o.scheduledDate.isNotEmpty) Text('Scheduled delivery: ${o.scheduledDate}'),
      ]))),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: navy)),
        ...o.items.map((x) => ListTile(contentPadding: EdgeInsets.zero, title: Text(x.product), trailing: Text('× ${x.qty}', style: const TextStyle(fontWeight: FontWeight.w800)))), const Divider(),
        Row(children: [const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text('₦${o.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy))]),
      ]))),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Delivery actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: navy)), const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonal(onPressed: () {}, child: const Text('Call customer')), FilledButton.tonal(onPressed: () {}, child: const Text('WhatsApp')), FilledButton.tonal(onPressed: () {}, child: const Text('Navigate')),
          if (widget.role == 'Admin' && o.agent.isEmpty) FilledButton(onPressed: assignAgent, child: const Text('Assign Agent')),
          if (widget.role == 'Agent' && o.status == 'Awaiting Agent Acceptance') ...[
            FilledButton(onPressed: () => setStatus('Accepted'), child: const Text('Accept')), FilledButton.tonal(onPressed: () => setStatus('Cancelled'), child: const Text('Reject')),
          ],
          if (widget.role == 'Agent' && ['Accepted', 'Customer Chose Another Day'].contains(o.status)) FilledButton(onPressed: () => setStatus('Out for Delivery'), child: const Text('Out for Delivery')),
          if (widget.role == 'Agent' && o.status == 'Out for Delivery') ...[
            FilledButton(onPressed: deliver, child: const Text('Delivered')), FilledButton.tonal(onPressed: () => setStatus('Customer Not Available'), child: const Text('Not Available')), FilledButton.tonal(onPressed: () => setStatus('Unable to Meet Up'), child: const Text('Unable to Meet Up')), FilledButton.tonal(onPressed: postpone, child: const Text('Deliver Another Day')), FilledButton.tonal(onPressed: () => setStatus('Cancelled'), child: const Text('Cancelled')),
          ],
          if (o.status == 'Delivered') ...[
            FilledButton.tonal(onPressed: payment, child: const Text('Payment / Remittance')), FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptPage(order: o))), child: const Text('Generate Receipt')),
          ],
        ]),
      ]))),
    ],),
  );
  void assignAgent() => showDialog(context: context, builder: (_) => SimpleDialog(title: const Text('Assign available agent'), children: agents.where((a) => a.available).map((a) => SimpleDialogOption(onPressed: () { setState(() { o.agent = a.name; o.status = 'Awaiting Agent Acceptance'; }); Navigator.pop(context); }, child: Text('${a.name} • ${a.state}'))).toList()));
  void deliver() { if (o.status == 'Delivered') return; final a = agents.firstWhere((a) => a.name == o.agent, orElse: () => agents.first); for (final item in o.items) { final old = a.stock[item.product] ?? 0; a.stock[item.product] = old - item.qty; } setState(() => o.status = 'Delivered'); }
  void postpone() { final d = TextEditingController(text: o.scheduledDate); showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Choose new delivery date'), content: TextField(controller: d, decoration: const InputDecoration(labelText: 'YYYY-MM-DD')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { o.scheduledDate = d.text.trim(); setState(() => o.status = 'Customer Chose Another Day'); Navigator.pop(context); }, child: const Text('Save'))])); }
  void payment() { final charged = TextEditingController(text: o.amountCharged == 0 ? o.total.toStringAsFixed(0) : o.amountCharged.toStringAsFixed(0)); final remitted = TextEditingController(text: o.amountRemitted.toStringAsFixed(0)); final extra = TextEditingController(text: o.extraCharge.toStringAsFixed(0)); final reason = TextEditingController(text: o.extraReason); String method = o.paymentMethod.isEmpty ? 'Cash' : o.paymentMethod; showDialog(context: context, builder: (_) => StatefulBuilder(builder: (c, set) => AlertDialog(title: const Text('Payment & Remittance'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: charged, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount charged')), TextField(controller: remitted, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount remitted')), TextField(controller: extra, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Extra charge (if any)')), TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason for extra charge')), DropdownButtonFormField<String>(value: method, items: const ['Cash', 'Bank Transfer'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (x) => set(() => method = x!), decoration: const InputDecoration(labelText: 'Payment method'))])), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), FilledButton(onPressed: () { o.amountCharged = double.tryParse(charged.text) ?? o.total; o.amountRemitted = double.tryParse(remitted.text) ?? 0; o.extraCharge = double.tryParse(extra.text) ?? 0; o.extraReason = reason.text; o.paymentMethod = method; setState(() {}); Navigator.pop(c); }, child: const Text('Save'))]))); }
}
class StatusPill extends StatelessWidget { final String status; const StatusPill(this.status, {super.key}); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: blue.withOpacity(.09), borderRadius: BorderRadius.circular(30)), child: Text(status, style: const TextStyle(color: blue, fontSize: 11, fontWeight: FontWeight.w800))); }

class NewOrderDialog extends StatefulWidget { const NewOrderDialog({super.key}); @override State<NewOrderDialog> createState() => _NewOrderState(); }
class _NewOrderState extends State<NewOrderDialog> {
  final name=TextEditingController(), ph=TextEditingController(), em=TextEditingController(), st=TextEditingController(), city=TextEditingController(), address=TextEditingController();
  final selected = <String, int>{};
  Product? chosen; int qty=1;
  double get total => selected.entries.fold(0, (sum,e) => sum + products.firstWhere((p)=>p.name==e.key).price * e.value);
  void addItem() { if (chosen == null) return; selected[chosen!.name] = (selected[chosen!.name] ?? 0) + qty; setState(() {}); }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('Create New Order'), content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(children: [
    field(name,'Customer name'), field(ph,'Customer phone'), field(em,'Customer email (optional)'), field(st,'State'), field(city,'City'), field(address,'Delivery address'),
    DropdownButtonFormField<Product>(value: chosen, items: products.map((p)=>DropdownMenuItem(value:p, child: Text(p.name))).toList(), onChanged:(v)=>setState(()=>chosen=v), decoration: const InputDecoration(labelText:'Product')),
    TextField(keyboardType:TextInputType.number, onChanged:(v)=>qty=int.tryParse(v)??1, decoration:const InputDecoration(labelText:'Quantity')),
    const SizedBox(height:8), SizedBox(width:double.infinity, child:FilledButton.tonal(onPressed:addItem, child:const Text('Add product / cross-sell'))),
    if(selected.isNotEmpty) ...[const SizedBox(height:12), Align(alignment:Alignment.centerLeft, child:Text('Order items',style:TextStyle(fontWeight:FontWeight.w900,color:navy))), ...selected.entries.map((e)=>ListTile(contentPadding:EdgeInsets.zero,title:Text(e.key),trailing:Text('× ${e.value}'))), const Divider(), Align(alignment:Alignment.centerRight,child:Text('Total: ₦${total.toStringAsFixed(0)}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:navy)))],
  ]))), actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')), FilledButton(onPressed:selected.isEmpty?null:(){final id='TZ-${(orders.length+125).toString().padLeft(6,'0')}'; final items=selected.entries.map((e)=>OrderItem(e.key,e.value)).toList(); orders.insert(0,Order(id:id,createdAt:DateTime.now(),customer:name.text.trim(),phone:ph.text.trim(),email:em.text.trim(),state:st.text.trim(),city:city.text.trim(),address:address.text.trim(),items:items,total:total)); Navigator.pop(context);},child:const Text('Create Order'))]);
  Widget field(TextEditingController c,String label)=>Padding(padding:const EdgeInsets.only(bottom:9),child:TextField(controller:c,decoration:InputDecoration(labelText:label)));
}

class AgentsPage extends StatefulWidget { final VoidCallback onChanged; const AgentsPage({super.key,required this.onChanged}); @override State<AgentsPage> createState()=>_AgentsState(); }
class _AgentsState extends State<AgentsPage> {
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[Row(children:[const Expanded(child:Text('Agents',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:navy))),FilledButton.icon(onPressed:addAgent,icon:const Icon(Icons.person_add),label:const Text('Add'))]),const SizedBox(height:12),...agents.map((a)=>Card(child:ExpansionTile(leading:CircleAvatar(child:Text(a.name.substring(0,1))),title:Text(a.name,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${a.phone} • ${a.state}'),trailing:Switch(value:a.available,onChanged:(v){setState(()=>a.available=v);widget.onChanged();}),children:[Padding(padding:const EdgeInsets.fromLTRB(16,0,16,16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Products in agent care',style:TextStyle(fontWeight:FontWeight.w900,color:navy)),...products.map((p)=>Row(children:[Expanded(child:Text(p.name)),Text('${a.stock[p.name]??0}'),const SizedBox(width:8),IconButton(onPressed:()=>adjustStock(a,p,1),icon:const Icon(Icons.add_circle_outline)),IconButton(onPressed:()=>adjustStock(a,p,-1),icon:const Icon(Icons.remove_circle_outline))]))]))]))]);
  void adjustStock(Agent a,Product p,int d){setState(()=>a.stock[p.name]=(a.stock[p.name]??0)+d);widget.onChanged();}
  void addAgent(){final n=TextEditingController(),ph=TextEditingController(),st=TextEditingController();showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('Add agent'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Full name')),TextField(controller:ph,decoration:const InputDecoration(labelText:'Phone')),TextField(controller:st,decoration:const InputDecoration(labelText:'State'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:(){agents.add(Agent(n.text,ph.text,st.text));Navigator.pop(context);setState((){});},child:const Text('Add agent'))]));}
}

class StockPage extends StatefulWidget { const StockPage({super.key}); @override State<StockPage> createState()=>_StockState(); }
class _StockState extends State<StockPage> {
  @override Widget build(BuildContext context){return ListView(padding:const EdgeInsets.all(16),children:[const Text('Inventory',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:navy)),const Text('Central stock and agent custody',style:TextStyle(color:Colors.grey)),const SizedBox(height:14),...products.map((p)=>Card(child:ListTile(leading:const Icon(Icons.inventory_2_outlined,color:blue),title:Text(p.name,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('Selling price: ₦${p.price.toStringAsFixed(0)}'),trailing:Text('${p.centralStock}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:navy)))),const SizedBox(height:20),const Text('Agent stock',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:navy)),...agents.map((a)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a.name,style:const TextStyle(fontWeight:FontWeight.w900)),...products.map((p)=>Row(children:[Expanded(child:Text(p.name)),Text('${a.stock[p.name]??0}',style:const TextStyle(fontWeight:FontWeight.w900))]))]))))]);}
}

class ReceiptsPage extends StatelessWidget { const ReceiptsPage({super.key}); @override Widget build(BuildContext context){final done=orders.where((o)=>o.status=='Delivered').toList();return ListView(padding:const EdgeInsets.all(16),children:[const Text('Customer Receipts',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:6),const Text('Branded receipts generated after successful delivery.',style:TextStyle(color:Colors.grey)),const SizedBox(height:14),if(done.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('No paid receipts yet.'))) else ...done.map((o)=>Card(child:ListTile(leading:const Icon(Icons.verified,color:green),title:Text(o.id,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${o.customer} • ${o.paymentMethod.isEmpty?'Payment not entered':o.paymentMethod}'),trailing:IconButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ReceiptPage(order:o))),icon:const Icon(Icons.open_in_new))))]);}}

class ReceiptPage extends StatelessWidget { final Order order; const ReceiptPage({super.key,required this.order}); @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Customer Receipt')),body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(18),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:520),child:Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(children:[const Logo(size:105),const SizedBox(height:10),const Text('TEMZ STORE',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:navy)),const Text(phone,style:TextStyle(color:blue,fontWeight:FontWeight.w700)),const Divider(height:32),const Text('CUSTOMER RECEIPT',style:TextStyle(letterSpacing:2,fontWeight:FontWeight.w900)),const SizedBox(height:14),_line('Receipt No.', 'R-${order.id.substring(3)}'),_line('TZ Order No.',order.id),_line('Customer',order.customer),_line('Phone',order.phone),_line('Address','${order.address}, ${order.city}, ${order.state}'),const SizedBox(height:12),...order.items.map((i)=>_line('${i.product} × ${i.qty}', '')),const Divider(),_line('TOTAL PAID','₦${order.total.toStringAsFixed(0)}'),_line('Payment Method',order.paymentMethod.isEmpty?'Cash':order.paymentMethod),const SizedBox(height:18),Container(padding:const EdgeInsets.symmetric(horizontal:28,vertical:10),decoration:BoxDecoration(border:Border.all(color:green,width:3),borderRadius:BorderRadius.circular(10)),child:const Text('PAID',style:TextStyle(color:green,fontSize:28,fontWeight:FontWeight.w900,letterSpacing:4))),const SizedBox(height:18),const Text('Thank you for shopping with Temz Store.',textAlign:TextAlign.center,style:TextStyle(color:Colors.grey)),const SizedBox(height:18),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Receipt is ready to share from your device.'))),icon:const Icon(Icons.share),label:const Text('SHARE RECEIPT'))]))))))); }
static Widget _line(String a,String b)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Text(a,style:const TextStyle(fontWeight:FontWeight.w700))),if(b.isNotEmpty)Flexible(child:Text(b,textAlign:TextAlign.right))])); }

class SettingsPage extends StatefulWidget { final String role; final VoidCallback onChanged; const SettingsPage({super.key,required this.role,required this.onChanged}); @override State<SettingsPage> createState()=>_SettingsState(); }
class _SettingsState extends State<SettingsPage>{
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[const Text('Settings',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:12),Card(child:ListTile(leading:const Icon(Icons.business,color:blue),title:const Text('Temz Store',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('09012533620'))),if(widget.role=='Admin') ...[
    Card(child:ListTile(onTap:manageAdmins,leading:const Icon(Icons.admin_panel_settings,color:blue),title:const Text('Admin Management'),subtitle:Text('${admins.length} initial admin accounts • add more admins'))),
    Card(child:ListTile(onTap:manageProducts,leading:const Icon(Icons.sell_outlined,color:blue),title:const Text('Products & Prices'),subtitle:const Text('Admin only • agents cannot edit prices'))),
  ],
  const Card(child:ListTile(leading:Icon(Icons.notifications_active,color:blue),title:Text('Agent reminders'),subtitle:Text('Every 3 hours until a final outcome'))),
  const Card(child:ListTile(leading:Icon(Icons.link,color:blue),title:Text('WordPress orders'),subtitle:Text('Secure webhook/API • cross-sells stay in one order'))),
  const Card(child:ListTile(leading:Icon(Icons.security,color:blue),title:Text('Security'),subtitle:Text('Admin/agent roles, device sessions and protected business data'))),
  ]);
  void manageAdmins(){final c=TextEditingController();showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('Admin Management'),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Current admin accounts: ${admins.length}'),const SizedBox(height:12),...admins.map((e)=>ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.verified_user_outlined),title:Text(e))),TextField(controller:c,decoration:const InputDecoration(labelText:'Add admin email'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close')),FilledButton(onPressed:(){final e=c.text.trim().toLowerCase();if(e.isNotEmpty)admins.add(e);Navigator.pop(context);setState((){});},child:const Text('Add'))]));}
  void manageProducts(){showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('Products & Prices'),content:SizedBox(width:500,child:SingleChildScrollView(child:Column(children:products.map((p){final c=TextEditingController(text:p.price.toStringAsFixed(0));return Padding(padding:const EdgeInsets.only(bottom:10),child:Row(children:[Expanded(child:Text(p.name)),const SizedBox(width:10),SizedBox(width:110,child:TextField(controller:c,keyboardType:TextInputType.number,decoration:const InputDecoration(prefixText:'₦'))),IconButton(onPressed:(){p.price=double.tryParse(c.text)??p.price;setState((){});},icon:const Icon(Icons.save_outlined))]);}).toList()))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Done'))]));}
}
