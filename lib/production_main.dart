import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

const navy = Color(0xFF071B3A);
const blue = Color(0xFF1264E8);
const bg = Color(0xFFF5F8FD);
const green = Color(0xFF159A63);
const red = Color(0xFFD92D4F);
const orange = Color(0xFFE58A00);
const url = 'https://xztnrpfrrqfxqfmboruc.supabase.co';
const key = 'sb_publishable_fFB3uYqNtygqBB_ARmKSdQ_qHU5SdTL';
const phone = '09012533620';
final supa = Supabase.instance.client;
const statuses = <String>['New Order','Awaiting Agent Acceptance','Accepted','Out for Delivery','Customer Not Available','Unable to Meet Up','Customer Chose Another Day','Delivered','Cancelled'];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: url, anonKey: key);
  runApp(const TZ());
}

class TZ extends StatelessWidget {
  const TZ({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'TZ • Temz Store',
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: bg, colorScheme: ColorScheme.fromSeed(seedColor: blue), fontFamily: 'Arial'),
    home: const Gate(),
  );
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 90});
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16)]), child: Image.asset('assets/temz_logo.jpg', fit: BoxFit.contain));
}

class Gate extends StatelessWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: supa.auth.onAuthStateChange,
    builder: (_, __) => supa.auth.currentSession == null ? const Login() : const RoleGate(),
  );
}

class RoleGate extends StatefulWidget {
  const RoleGate({super.key});
  @override State<RoleGate> createState() => _RoleGateState();
}
class _RoleGateState extends State<RoleGate> {
  String? role;
  String? name;
  String? error;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final id = supa.auth.currentUser!.id;
      final p = await supa.from('profiles').select('role,full_name').eq('id', id).maybeSingle();
      if (p == null) throw Exception('Your account has not been activated by a Temz Store administrator.');
      setState(() { role = p['role']; name = p['full_name'] ?? ''; });
    } catch (e) {
      await supa.auth.signOut();
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }
  }
  @override Widget build(BuildContext context) {
    if (error != null) return Login(message: error);
    if (role == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Shell(role: role!, name: name ?? '');
  }
}

class Login extends StatefulWidget {
  final String? message;
  const Login({super.key, this.message});
  @override State<Login> createState() => _LoginState();
}
class _LoginState extends State<Login> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool hide = true, busy = false;
  Future<void> signIn() async {
    setState(() => busy = true);
    try {
      await supa.auth.signInWithPassword(email: email.text.trim().toLowerCase(), password: password.text);
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Column(children: [
        const Logo(size: 160), const SizedBox(height: 18),
        const Text('TZ', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: navy)),
        const Text('TEMZ STORE OPERATIONS', style: TextStyle(letterSpacing: 2, color: blue, fontWeight: FontWeight.w800)),
        if (widget.message != null) Padding(padding: const EdgeInsets.only(top: 18), child: Text(widget.message!, textAlign: TextAlign.center, style: const TextStyle(color: red, fontWeight: FontWeight.w700))),
        const SizedBox(height: 28),
        Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline))),
          const SizedBox(height: 14),
          TextField(controller: password, obscureText: hide, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility : Icons.visibility_off)))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: navy), onPressed: busy ? null : signIn, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SIGN IN'))),
          const SizedBox(height: 12), const Text('Temz Store • 09012533620', style: TextStyle(color: Colors.grey)),
        ]))),
      ]),
    ))),
  );
}

class Shell extends StatefulWidget {
  final String role, name;
  const Shell({super.key, required this.role, required this.name});
  @override State<Shell> createState() => _ShellState();
}
class _ShellState extends State<Shell> {
  int tab = 0;
  final titles = const ['Dashboard','Orders','Agents','Stock','Receipts','Settings'];
  @override Widget build(BuildContext context) {
    final pages = [
      Dashboard(role: widget.role), Orders(role: widget.role), Agents(role: widget.role), Stock(role: widget.role), const Receipts(), Settings(role: widget.role),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(titles[tab], style: const TextStyle(fontWeight: FontWeight.w900, color: navy)), actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Logo(size: 42))]),
      drawer: Drawer(child: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [const Center(child: Logo(size: 95)), const Center(child: Text('TEMZ STORE', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: navy))), Center(child: Text(widget.role.toUpperCase(), style: const TextStyle(color: blue, fontWeight: FontWeight.w800))), const Divider(height: 30), ...List.generate(titles.length, (i) => ListTile(selected: i == tab, leading: Icon([Icons.grid_view, Icons.receipt_long, Icons.groups, Icons.inventory_2, Icons.request_quote, Icons.settings][i]), title: Text(titles[i]), onTap: () { setState(() => tab = i); Navigator.pop(context); })), const Divider(), ListTile(leading: const Icon(Icons.logout), title: const Text('Log out'), onTap: () => supa.auth.signOut())]))),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [NavigationDestination(icon: Icon(Icons.grid_view), label: 'Home'), NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'), NavigationDestination(icon: Icon(Icons.groups), label: 'Agents'), NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Stock'), NavigationDestination(icon: Icon(Icons.request_quote), label: 'Receipts'), NavigationDestination(icon: Icon(Icons.settings), label: 'Settings')]),
    );
  }
}

Future<List<Map<String,dynamic>>> ordersFor(String role) async {
  var q = supa.from('orders').select('id,order_number,created_at,customer_name,customer_phone,customer_email,state,city,delivery_address,assigned_agent_id,status,scheduled_delivery_date,total_amount,amount_charged,amount_remitted,extra_charge,extra_charge_reason,payment_method,receipt_generated');
  if (role == 'agent') q = q.eq('assigned_agent_id', supa.auth.currentUser!.id);
  return List<Map<String,dynamic>>.from(await q.order('created_at', ascending: false));
}
Future<List<Map<String,dynamic>>> itemsFor(String id) async => List<Map<String,dynamic>>.from(await supa.from('order_items').select('quantity,unit_price,products(name)').eq('order_id', id));

class Dashboard extends StatefulWidget { final String role; const Dashboard({super.key, required this.role}); @override State<Dashboard> createState()=>_DashboardState(); }
class _DashboardState extends State<Dashboard> {
  late Future<List<Map<String,dynamic>>> future;
  @override void initState(){super.initState();future=ordersFor(widget.role);}
  @override Widget build(BuildContext context)=>FutureBuilder(future: future,builder:(context,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());final x=s.data!;int n(String st)=>x.where((o)=>o['status']==st).length;final rem=x.where((o)=>o['status']=='Delivered'&&(num.tryParse('${o['amount_remitted']??0}')??0)<(num.tryParse('${o['amount_charged']??0}')??0)).length;return RefreshIndicator(onRefresh:()async{setState(()=>future=ordersFor(widget.role));await future;},child:ListView(padding:const EdgeInsets.all(16),children:[Text(widget.role=='admin'?'Good day, Admin':'Agent dashboard',style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:20),GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.45,children:[Stat('New Orders',n('New Order'),blue),Stat('Awaiting Acceptance',n('Awaiting Agent Acceptance'),orange),Stat('Out for Delivery',n('Out for Delivery'),navy),Stat('Delivered',n('Delivered'),green),Stat('Postponed',n('Customer Chose Another Day'),orange),Stat('Cancelled',n('Cancelled'),red),Stat('Awaiting Remittance',rem,Colors.purple)]),const SizedBox(height:22),const Text('Recent orders',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:8),...x.take(8).map((o)=>Card(child:ListTile(leading:CircleAvatar(backgroundColor:blue.withOpacity(.1),child:const Icon(Icons.receipt_long,color:blue)),title:Text(o['order_number'],style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${o['customer_name']} • ${o['status']}'),trailing:Text('₦${o['total_amount']}'))))]));}
}
class Stat extends StatelessWidget { final String title; final int value; final Color color; const Stat(this.title,this.value,this.color,{super.key}); @override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Icon(Icons.circle,color:color,size:16),Text('$value',style:const TextStyle(fontSize:27,fontWeight:FontWeight.w900,color:navy)),Text(title,style:TextStyle(fontSize:11,color:Colors.grey.shade600,fontWeight:FontWeight.w700))]))); }

class Orders extends StatefulWidget { final String role; const Orders({super.key,required this.role}); @override State<Orders> createState()=>_OrdersState(); }
class _OrdersState extends State<Orders>{String filter='All',search='';late Future<List<Map<String,dynamic>>> future;@override void initState(){super.initState();future=ordersFor(widget.role);}void reload()=>setState(()=>future=ordersFor(widget.role));@override Widget build(BuildContext c)=>FutureBuilder(future:future,builder:(c,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());final list=s.data!.where((o)=>(filter=='All'||o['status']==filter)&&'${o['order_number']} ${o['customer_name']} ${o['customer_phone']}'.toLowerCase().contains(search.toLowerCase())).toList();return Column(children:[Padding(padding:const EdgeInsets.fromLTRB(16,8,16,6),child:TextField(onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(hintText:'Search order, customer or phone',prefixIcon:Icon(Icons.search)))),SizedBox(height:44,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:14),children:['All',...statuses].map((x)=>Padding(padding:const EdgeInsets.only(right:6),child:ChoiceChip(label:Text(x,style:const TextStyle(fontSize:10)),selected:filter==x,onSelected:(_)=>setState(()=>filter=x)))).toList())),Expanded(child:RefreshIndicator(onRefresh:()async{reload();await future;},child:ListView(padding:const EdgeInsets.all(14),children:list.map((o)=>Card(child:ListTile(onTap:()async{await Navigator.push(c,MaterialPageRoute(builder:(_)=>OrderDetail(order:o,role:widget.role)));reload();},leading:StatusIcon(o['status']),title:Text(o['order_number'],style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${o['customer_name']}\n${o['city']}, ${o['state']}'),isThreeLine:true))).toList())))]) ;});}
}
class StatusIcon extends StatelessWidget{final String status;const StatusIcon(this.status,{super.key});@override Widget build(BuildContext c){final color=status=='Delivered'?green:status=='Cancelled'?red:(status.contains('Not')||status.contains('Unable')||status.contains('Another')?orange:blue);return CircleAvatar(backgroundColor:color.withOpacity(.1),child:Icon(status=='Delivered'?Icons.check:Icons.local_shipping_outlined,color:color));}}

class OrderDetail extends StatefulWidget{final Map<String,dynamic> order;final String role;const OrderDetail({super.key,required this.order,required this.role});@override State<OrderDetail> createState()=>_OrderDetailState();}
class _OrderDetailState extends State<OrderDetail>{late Map<String,dynamic> o;List<Map<String,dynamic>> items=[];bool loading=true;@override void initState(){super.initState();o=Map.from(widget.order);load();}Future<void> load()async{items=await itemsFor(o['id']);if(mounted)setState(()=>loading=false);}Future<void> openUrl(String s)async{final u=Uri.parse(s);if(await canLaunchUrl(u))await launchUrl(u,mode:LaunchMode.externalApplication);}Future<void> agentAction(String status,{String? date})async{try{await supa.rpc('tz_agent_update_order',params:{'p_order':o['id'],'p_status':status,'p_scheduled_date':date});await refreshOrder();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}Future<void> refreshOrder()async{final r=await supa.from('orders').select().eq('id',o['id']).single();setState(()=>o=r);await load();}
Future<void> assign()async{final a=await supa.from('profiles').select('id,full_name,state').eq('role','agent').eq('available',true);if(!mounted)return;showModalBottomSheet(context:context,builder:(_)=>ListView(padding:const EdgeInsets.all(16),children:[const Text('Assign available agent',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:navy)),...a.map((x)=>ListTile(title:Text(x['full_name']),subtitle:Text(x['state']??''),onTap:()async{await supa.rpc('tz_assign_order',params:{'p_order':o['id'],'p_agent':x['id']});if(mounted)Navigator.pop(context);await refreshOrder();}))]));}
Future<void> delivered()async{final charged=TextEditingController(text:'${o['total_amount']}');final remitted=TextEditingController(text:'0');final extra=TextEditingController(text:'0');final reason=TextEditingController();String method='Cash';await showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(c,set)=>AlertDialog(title:const Text('Confirm delivery'),content:SingleChildScrollView(child:Column(children:[TextField(controller:charged,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Amount charged')),TextField(controller:remitted,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Amount remitted')),TextField(controller:extra,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Extra charge')),TextField(controller:reason,decoration:const InputDecoration(labelText:'Reason for extra charge')),DropdownButtonFormField<String>(value:method,items:const['Cash','Bank Transfer'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>set(()=>method=x!),decoration:const InputDecoration(labelText:'Payment method'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:()async{try{await supa.rpc('tz_agent_update_order',params:{'p_order':o['id'],'p_status':'Delivered','p_amount_charged':double.tryParse(charged.text),'p_amount_remitted':double.tryParse(remitted.text)??0,'p_extra_charge':double.tryParse(extra.text)??0,'p_extra_reason':reason.text.trim().isEmpty?null:reason.text.trim(),'p_payment_method':method});if(c.mounted)Navigator.pop(c);await refreshOrder();}catch(e){ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text('$e')));}},child:const Text('Mark Delivered'))])));}
@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(o['order_number']??'')),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(o['customer_name']??'',style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:navy))),Pill(o['status'])]),const SizedBox(height:8),Text(o['customer_phone']??'',style:const TextStyle(color:blue,fontWeight:FontWeight.w700)),const SizedBox(height:12),Text('${o['delivery_address']}\n${o['city']}, ${o['state']}'),if(o['scheduled_delivery_date']!=null)Text('Scheduled: ${o['scheduled_delivery_date']}')])),Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Products',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:navy)),...items.map((i)=>ListTile(contentPadding:EdgeInsets.zero,title:Text(i['products']?['name']??'Product'),trailing:Text('× ${i['quantity']}'))),const Divider(),Text('TOTAL: ₦${o['total_amount']}',style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy))])),Card(child:Padding(padding:const EdgeInsets.all(18),child:Wrap(spacing:8,runSpacing:8,children:[FilledButton.tonal(onPressed:()=>openUrl('tel:${o['customer_phone']}'),child:const Text('Call')),FilledButton.tonal(onPressed:()=>openUrl('https://wa.me/234${o['customer_phone'].toString().replaceFirst(RegExp('^0'), '')}'),child:const Text('WhatsApp')),FilledButton.tonal(onPressed:()=>openUrl('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${o['delivery_address']}, ${o['city']}, ${o['state']} Nigeria')}'),child:const Text('Navigate')),if(widget.role=='admin'&&o['assigned_agent_id']==null)FilledButton(onPressed:assign,child:const Text('Assign Agent')),if(widget.role=='agent'&&o['status']=='Awaiting Agent Acceptance')... [FilledButton(onPressed:()=>agentAction('Accepted'),child:const Text('Accept')),FilledButton.tonal(onPressed:()=>agentAction('Cancelled'),child:const Text('Reject'))],if(widget.role=='agent'&&['Accepted','Customer Chose Another Day'].contains(o['status']))FilledButton(onPressed:()=>agentAction('Out for Delivery'),child:const Text('Out for Delivery')),if(widget.role=='agent'&&o['status']=='Out for Delivery')... [FilledButton(onPressed:delivered,child:const Text('Delivered')),FilledButton.tonal(onPressed:()=>agentAction('Customer Not Available'),child:const Text('Not Available')),FilledButton.tonal(onPressed:()=>agentAction('Unable to Meet Up'),child:const Text('Unable to Meet Up')),FilledButton.tonal(onPressed:()=>agentAction('Cancelled'),child:const Text('Cancelled'))],if(o['status']=='Delivered')FilledButton(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Receipt(order:o,items:items))),child:const Text('Generate Receipt'))]))])]);}
}
class Pill extends StatelessWidget{final String text;const Pill(this.text,{super.key});@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),decoration:BoxDecoration(color:blue.withOpacity(.1),borderRadius:BorderRadius.circular(30)),child:Text(text,style:const TextStyle(color:blue,fontSize:11,fontWeight:FontWeight.w800)));}

class Agents extends StatefulWidget{final String role;const Agents({super.key,required this.role});@override State<Agents> createState()=>_AgentsState();}
class _AgentsState extends State<Agents>{late Future<List<Map<String,dynamic>>> f;@override void initState(){super.initState();f=load();}Future<List<Map<String,dynamic>>> load()=>Future.value(List<Map<String,dynamic>>.from(supa.from('profiles').select('id,full_name,email,phone,state,available').eq('role','agent')));@override Widget build(BuildContext c)=>FutureBuilder(future:f,builder:(c,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());return RefreshIndicator(onRefresh:()async{setState(()=>f=load());await f;},child:ListView(padding:const EdgeInsets.all(16),children:[Text('Agents (${s.data!.length})',style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:12),...s.data!.map((a)=>Card(child:SwitchListTile(value:a['available']??true,onChanged:widget.role=='admin'?(v)async{await supa.from('profiles').update({'available':v}).eq('id',a['id']);setState(()=>f=load());}:null,title:Text(a['full_name']??'',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${a['phone']??''} • ${a['state']??''}'),secondary:const Icon(Icons.person_outline,color:blue))))]));});}
}
class Stock extends StatefulWidget{final String role;const Stock({super.key,required this.role});@override State<Stock> createState()=>_StockState();}
class _StockState extends State<Stock>{late Future<List<Map<String,dynamic>>> f;@override void initState(){super.initState();f=load();}Future<List<Map<String,dynamic>>> load()=>Future.value(List<Map<String,dynamic>>.from(supa.from('products').select('id,name,selling_price,central_stock,active').order('name')));@override Widget build(BuildContext c)=>FutureBuilder(future:f,builder:(c,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());return ListView(padding:const EdgeInsets.all(16),children:[const Text('Central Stock',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:navy)),const Text('Only admins control product prices and central stock.',style:TextStyle(color:Colors.grey)),const SizedBox(height:14),...s.data!.map((p)=>Card(child:ListTile(title:Text(p['name'],style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('₦${p['selling_price']}'),leading:const Icon(Icons.inventory_2_outlined,color:blue),trailing:Text('${p['central_stock']}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:navy))))]));});}
}
class Receipts extends StatefulWidget{const Receipts({super.key});@override State<Receipts> createState()=>_ReceiptsState();}
class _ReceiptsState extends State<Receipts>{late Future<List<Map<String,dynamic>>> f;@override void initState(){super.initState();f=load();}Future<List<Map<String,dynamic>>> load()=>Future.value(List<Map<String,dynamic>>.from(supa.from('orders').select('id,order_number,customer_name,customer_phone,delivery_address,city,state,total_amount,payment_method,receipt_generated').eq('status','Delivered').order('created_at',ascending:false)));@override Widget build(BuildContext c)=>FutureBuilder(future:f,builder:(c,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());return ListView(padding:const EdgeInsets.all(16),children:[const Text('Customer Receipts',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:8),...s.data!.map((o)=>Card(child:ListTile(leading:const Icon(Icons.verified,color:green),title:Text(o['order_number']),subtitle:Text('${o['customer_name']} • ${o['payment_method']??''}'),trailing:IconButton(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Receipt(order:o,items:const[]))),icon:const Icon(Icons.open_in_new))))]));});}
}
class Receipt extends StatelessWidget{final Map<String,dynamic> order;final List<Map<String,dynamic>> items;const Receipt({super.key,required this.order,required this.items});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Customer Receipt')),body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(18),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:520),child:Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(children:[const Logo(size:105),const Text('TEMZ STORE',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:navy)),const Text(phone,style:TextStyle(color:blue,fontWeight:FontWeight.w700)),const Divider(height:30),const Text('CUSTOMER RECEIPT',style:TextStyle(letterSpacing:2,fontWeight:FontWeight.w900)),const SizedBox(height:12),row('TZ Order No.',order['order_number']),row('Customer',order['customer_name']),row('Phone',order['customer_phone']),row('Address','${order['delivery_address']}, ${order['city']}, ${order['state']}'),...items.map((i)=>row('${i['products']?['name']??'Product'} × ${i['quantity']}','')),const Divider(),row('TOTAL PAID','₦${order['total_amount']}'),row('Payment Method',order['payment_method']??'Cash'),const SizedBox(height:18),Container(padding:const EdgeInsets.symmetric(horizontal:28,vertical:10),decoration:BoxDecoration(border:Border.all(color:green,width:3),borderRadius:BorderRadius.circular(10)),child:const Text('PAID',style:TextStyle(color:green,fontSize:28,fontWeight:FontWeight.w900,letterSpacing:4))),const SizedBox(height:18),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>Share.share('TEMZ STORE\nOrder: ${order['order_number']}\nCustomer: ${order['customer_name']}\nTOTAL PAID: ₦${order['total_amount']}\nPayment: ${order['payment_method']??'Cash'}\nPAID\n09012533620'),icon:const Icon(Icons.share),label:const Text('SHARE RECEIPT'))])))))));static Widget row(String a,String b)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[Expanded(child:Text(a,style:const TextStyle(fontWeight:FontWeight.w700))),Flexible(child:Text(b,textAlign:TextAlign.right))]));}
class Settings extends StatelessWidget{final String role;const Settings({super.key,required this.role});@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[const Text('Settings',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:12),const Card(child:ListTile(leading:Icon(Icons.business,color:blue),title:Text('Temz Store',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(phone))),const Card(child:ListTile(leading:Icon(Icons.notifications_active,color:blue),title:Text('Agent reminders'),subtitle:Text('Every 3 hours until a final outcome'))),const Card(child:ListTile(leading:Icon(Icons.link,color:blue),title:Text('WordPress orders'),subtitle:Text('Secure webhook • cross-sells stay in one order'))),const Card(child:ListTile(leading:Icon(Icons.security,color:blue),title:Text('Supabase Auth + RLS'),subtitle:Text('Agents see assigned orders only'))),FilledButton.tonalIcon(onPressed:()=>supa.auth.signOut(),icon:const Icon(Icons.logout),label:const Text('Log out'))]);}
