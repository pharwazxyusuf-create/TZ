from pathlib import Path
import re

AUTH_REDIRECT = 'tz://auth-callback/'

source = Path('lib/tz_build.dart')
s = source.read_text(encoding='utf-8')

# Use the current Supabase client API and explicit PKCE for mobile auth links.
s = s.replace(
    "await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);",
    "await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey, authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce));"
)

for import_line, after in [
    ("import 'package:flutter_svg/flutter_svg.dart';", "import 'package:flutter/material.dart';"),
    ("import 'package:share_plus/share_plus.dart';", "import 'package:flutter_svg/flutter_svg.dart';"),
    ("import 'password_pages.dart';", "import 'package:supabase_flutter/supabase_flutter.dart';"),
    ("import 'admin_setup.dart';", "import 'password_pages.dart';"),
]:
    if import_line not in s:
        s = s.replace(after, after + '\n' + import_line)

# Replace the old raster logo container. The previous JPEG produced a large grey block on device.
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

# Login actions: password recovery + first-time admin setup.
anchor = "SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : login, child: busy ? const CircularProgressIndicator() : const Text('SIGN IN'))),"
if "Forgot Password?" not in s and anchor in s:
    s = s.replace(anchor, anchor + "\n                          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())), child: const Text('Forgot Password?'))),\n                          TextButton(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSetupPage())), child: const Text('First-time admin setup')), ")

# Friendly network handling.
old = "    } on AuthException catch (e) {\n      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));\n    } finally {"
new = "    } on AuthException catch (e) {\n      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));\n    } catch (_) {\n      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to connect to Temz Store. Please check your internet connection and try again.')));\n    } finally {"
if old in s:
    s = s.replace(old, new)

# Profile gate now enforces first-time agent password setup.
profile_start = s.find('class ProfileGate extends StatefulWidget {')
home_start = s.find('class HomeShell extends StatefulWidget {')
if profile_start >= 0 and home_start > profile_start:
    profile = '''class SetPasswordPage extends StatefulWidget {
  const SetPasswordPage({super.key});
  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  bool hide = true;

  Future<void> save() async {
    if (password.text.length < 8 || password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords must match and contain at least 8 characters.')));
      return;
    }
    setState(() => busy = true);
    try {
      await db.auth.updateUser(UserAttributes(password: password.text));
      await db.rpc('tz_complete_agent_setup');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ProfileGate()), (route) => false);
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Setup failed: $e')));
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
                const Logo(size: 120),
                const SizedBox(height: 18),
                const Text('Welcome to TZ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: navy)),
                const SizedBox(height: 8),
                const Text('Set your personal password before entering your agent dashboard.', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(controller: password, obscureText: hide, decoration: InputDecoration(labelText: 'Create password (8+ characters)', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility : Icons.visibility_off)))),
                const SizedBox(height: 14),
                TextField(controller: confirm, obscureText: hide, decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.verified_user_outlined))),
                const SizedBox(height: 22),
                SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : save, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SET PASSWORD & CONTINUE'))),
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
  bool? passwordSet;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final user = db.auth.currentUser;
      if (user == null) return;
      final row = await db.from('profiles').select('role,full_name,password_set').eq('id', user.id).maybeSingle();
      if (row == null) throw Exception('Your account has not been activated by a Temz Store administrator.');
      if (!mounted) return;
      setState(() {
        role = '${row['role'] ?? 'agent'}';
        name = '${row['full_name'] ?? ''}';
        passwordSet = row['password_set'] == null ? true : row['password_set'] as bool;
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
    if (role == 'agent' && passwordSet == false) return const SetPasswordPage();
    return HomeShell(role: role!, name: name);
  }
}

'''
    s = s[:profile_start] + profile + s[home_start:]

# Make navigation role-aware and keep the agent interface simple.
home_start = s.find('class HomeShell extends StatefulWidget {')
orders_loader = s.find('Future<List<Map<String, dynamic>>> loadOrders(String role) async {')
if home_start >= 0 and orders_loader > home_start:
    home = '''class HomeShell extends StatefulWidget {
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
    final titles = isAdmin ? const ['Dashboard', 'Orders', 'Agents', 'Stock'] : const ['Dashboard', 'Orders', 'My Stock'];
    final pages = isAdmin
        ? <Widget>[DashboardPage(role: widget.role, name: widget.name), OrdersPage(role: widget.role), const AgentsPage(), StockPage(role: widget.role)]
        : <Widget>[DashboardPage(role: widget.role, name: widget.name), OrdersPage(role: widget.role), StockPage(role: widget.role)];
    if (index >= pages.length) index = 0;
    final icons = isAdmin ? const [Icons.grid_view, Icons.receipt_long, Icons.groups, Icons.inventory_2] : const [Icons.grid_view, Icons.receipt_long, Icons.inventory_2];
    final labels = isAdmin ? const ['Home', 'Orders', 'Agents', 'Stock'] : const ['Home', 'Orders', 'Stock'];

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
              const Center(child: Logo(size: 105)),
              const SizedBox(height: 8),
              const Center(child: Text('TEMZ STORE', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: navy))),
              Center(child: Text(widget.role.toUpperCase(), style: const TextStyle(color: blue, fontWeight: FontWeight.w800))),
              const Divider(height: 30),
              for (int i = 0; i < titles.length; i++)
                ListTile(selected: i == index, leading: Icon(icons[i]), title: Text(titles[i]), onTap: () { setState(() => index = i); Navigator.pop(context); }),
              const Divider(),
              ListTile(leading: const Icon(Icons.lock_reset), title: const Text('Change password'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage()))),
              ListTile(leading: const Icon(Icons.logout), title: const Text('Log out'), onTap: () => db.auth.signOut()),
            ],
          ),
        ),
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [for (int i = 0; i < labels.length; i++) NavigationDestination(icon: Icon(icons[i]), label: labels[i])],
      ),
    );
  }
}

'''
    s = s[:home_start] + home + s[orders_loader:]

# Replace AgentsPage with real admin-only agent creation and shareable access links.
ag_start = s.find('class AgentsPage extends StatelessWidget {')
stock_start = s.find('class StockPage extends StatelessWidget {')
if ag_start >= 0 and stock_start > ag_start:
    agents = r'''class AgentsPage extends StatefulWidget {
  const AgentsPage({super.key});
  @override
  State<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends State<AgentsPage> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() { super.initState(); future = loadAgents(); }

  Future<List<Map<String, dynamic>>> loadAgents() async {
    final rows = await db.from('profiles').select('id,full_name,email,phone,state,available,password_set').eq('role', 'agent').order('full_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  void refresh() => setState(() => future = loadAgents());

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: Text('Agents error: ${snap.error}'));
      final rows = snap.data ?? <Map<String, dynamic>>[];
      return RefreshIndicator(
        onRefresh: () async { refresh(); await future; },
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Agents', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy)),
              FilledButton.icon(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentInvitePage())); refresh(); }, icon: const Icon(Icons.person_add_alt_1), label: const Text('ADD AGENT')),
            ]),
            const SizedBox(height: 8),
            Text('${rows.length} agent${rows.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            for (final a in rows)
              Card(child: ListTile(
                leading: CircleAvatar(child: Text('${a['full_name'] ?? 'A'}'.trim().isEmpty ? 'A' : '${a['full_name']}'.trim()[0].toUpperCase())),
                title: Text('${a['full_name'] ?? 'Unnamed agent'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${a['email'] ?? ''}\n${a['state'] ?? 'State not set'} • ${a['available'] == true ? 'Available' : 'Unavailable'}'),
                isThreeLine: true,
                trailing: Icon(a['password_set'] == true ? Icons.verified_user : Icons.key_off, color: a['password_set'] == true ? green : orange),
              )),
          ],
        ),
      );
    },
  );
}

class AgentInvitePage extends StatefulWidget {
  const AgentInvitePage({super.key});
  @override
  State<AgentInvitePage> createState() => _AgentInvitePageState();
}

class _AgentInvitePageState extends State<AgentInvitePage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final state = TextEditingController();
  bool busy = false;

  Future<void> createLink() async {
    final n = name.text.trim();
    final e = email.text.trim().toLowerCase();
    if (n.isEmpty || !e.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the agent name and a valid email.')));
      return;
    }
    setState(() => busy = true);
    try {
      final res = await db.functions.invoke('admin-invite-agent', body: {'full_name': n, 'email': e, 'phone': phone.text.trim(), 'state': state.text.trim()});
      final data = Map<String, dynamic>.from(res.data as Map);
      final link = '${data['action_link'] ?? ''}'.trim();
      if (link.isEmpty) throw Exception('The server did not return an access link.');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Agent access link created'),
          content: SelectableText('Send this private link to the agent:\n\n$link\n\nWhen the agent opens it on a phone with TZ installed, TZ will open and ask them to create their personal password.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
            FilledButton.icon(onPressed: () async { await SharePlus.instance.share(ShareParams(text: 'TZ Agent Access\n\nHello $n,\nOpen this private link on the phone where TZ is installed:\n\n$link\n\nAfter TZ opens, create your personal password.\n\nTemz Store')); }, icon: const Icon(Icons.share), label: const Text('SHARE LINK')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create agent link: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add Agent')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Create agent access', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 8),
        const Text('TZ will create the agent account and give you a private access link you can share by WhatsApp.'),
        const SizedBox(height: 22),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Agent full name', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 14),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Agent email', prefixIcon: Icon(Icons.email_outlined))),
        const SizedBox(height: 14),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined))),
        const SizedBox(height: 14),
        TextField(controller: state, decoration: const InputDecoration(labelText: 'State', prefixIcon: Icon(Icons.location_on_outlined))),
        const SizedBox(height: 24),
        SizedBox(height: 52, child: FilledButton.icon(onPressed: busy ? null : createLink, icon: const Icon(Icons.link), label: Text(busy ? 'CREATING LINK...' : 'CREATE & SHARE ACCESS LINK'))),
      ],
    ),
  );
}

'''
    s = s[:ag_start] + agents + s[stock_start:]

# Replace stock page with role-aware central/agent stock.
marker = 'class StockPage extends StatelessWidget {'
if marker in s:
    prefix = s.split(marker, 1)[0]
    replacement = r'''class StockPage extends StatelessWidget {
  final String role;
  const StockPage({super.key, required this.role});
  @override
  Widget build(BuildContext context) {
    final isAgent = role == 'agent';
    final future = isAgent
        ? db.from('agent_stock').select('quantity,products(name,selling_price)').eq('agent_id', db.auth.currentUser!.id).order('updated_at', ascending: false)
        : db.from('products').select('id,name,selling_price,central_stock').order('name');
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Stock error: ${snapshot.error}'));
        final rows = snapshot.data ?? <Map<String, dynamic>>[];
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text(isAgent ? 'My Stock' : 'Central Stock', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy)),
            const SizedBox(height: 10),
            if (rows.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No stock records yet.'))),
            for (final product in rows)
              Card(child: ListTile(
                title: Text(isAgent ? '${(product['products'] as Map?)?['name'] ?? 'Product'}' : '${product['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(isAgent ? 'In your care' : 'Selling price: ₦${product['selling_price'] ?? 0}'),
                trailing: Text('${isAgent ? product['quantity'] ?? 0 : product['central_stock'] ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              )),
          ],
        );
      },
    );
  }
}
'''
    s = prefix + replacement

# Auth stream errors must not crash the app.
s = s.replace('stream: db.auth.onAuthStateChange,', 'stream: db.auth.onAuthStateChange.handleError((_) {}),')

# Generate Android/iOS platform deep-link configuration after flutter create.
manifest = Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
    m = manifest.read_text(encoding='utf-8')
    permission = '<uses-permission android:name="android.permission.INTERNET" />'
    if permission not in m:
        opening_end = m.find('>')
        if opening_end != -1 and '<manifest' in m[:opening_end + 1]:
            m = m[:opening_end + 1] + '\n    ' + permission + m[opening_end + 1:]
    if 'android:scheme="tz"' not in m:
        activity_match = re.search(r'(<activity[^>]+android:name="[^"]*MainActivity"[^>]*>)', m)
        if activity_match:
            activity_tag = activity_match.group(1)
            intent = '''\n            <intent-filter>\n                <action android:name="android.intent.action.VIEW" />\n                <category android:name="android.intent.category.DEFAULT" />\n                <category android:name="android.intent.category.BROWSABLE" />\n                <data android:scheme="tz" android:host="auth-callback" />\n            </intent-filter>'''
            m = m.replace(activity_tag, activity_tag + intent, 1)
    manifest.write_text(m, encoding='utf-8')

plist = Path('ios/Runner/Info.plist')
if plist.exists():
    p = plist.read_text(encoding='utf-8')
    if 'CFBundleURLSchemes' not in p:
        insert = '''\n\t<key>CFBundleURLTypes</key>\n\t<array>\n\t\t<dict>\n\t\t\t<key>CFBundleTypeRole</key>\n\t\t\t<string>Editor</string>\n\t\t\t<key>CFBundleURLSchemes</key>\n\t\t\t<array>\n\t\t\t\t<string>tz</string>\n\t\t\t</array>\n\t\t</dict>\n\t</array>\n'''
        p = p.replace('</dict>\n</plist>', insert + '</dict>\n</plist>')
    plist.write_text(p, encoding='utf-8')

print('TZ final auth, agent onboarding, logo, and mobile deep-link fixes applied successfully.')
