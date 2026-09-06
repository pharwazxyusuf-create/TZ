from pathlib import Path

p = Path('lib/tz_build.dart')
s = p.read_text(encoding='utf-8')

# Login: add a simple self-registration entry point.
anchor = "Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())), child: const Text('Forgot Password?'))),"
if "Register as Agent" not in s and anchor in s:
    s = s.replace(
        anchor,
        anchor + "\n                          TextButton(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentRegistrationPage())), child: const Text('Register as Agent')),"
    )

# Agents must be approved before they can enter TZ.
start = s.find('class ProfileGate extends StatefulWidget {')
end = s.find('class HomeShell extends StatefulWidget {')
if start >= 0 and end > start:
    profile = '''class ProfileGate extends StatefulWidget {
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
      final row = await db.from('profiles').select('role,full_name,password_set,available,agent_approval_status').eq('id', user.id).maybeSingle();
      if (row == null) throw Exception('Your account has not been activated by a Temz Store administrator.');

      final r = '${row['role'] ?? 'agent'}';
      final approval = '${row['agent_approval_status'] ?? 'approved'}';
      if (r == 'agent' && approval == 'pending') {
        throw Exception('Your agent registration is awaiting admin approval.');
      }
      if (r == 'agent' && approval == 'rejected') {
        throw Exception('Your agent registration was not approved. Please contact Temz Store.');
      }
      if (r == 'agent' && row['available'] == false) {
        throw Exception('Your Temz Store agent account is currently inactive. Contact an administrator.');
      }

      if (!mounted) return;
      setState(() {
        role = r;
        name = '${row['full_name'] ?? ''}';
        passwordSet = row['password_set'] == null ? true : row['password_set'] as bool;
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
    if (role == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (role == 'agent' && passwordSet == false) return const SetPasswordPage();
    return HomeShell(role: role!, name: name);
  }
}

'''
    s = s[:start] + profile + s[end:]

# Replace the old invitation UI with a simple pending/approve/reject screen.
start = s.find('class AgentsPage extends StatefulWidget {')
end = s.find('class StockPage extends StatelessWidget {')
if start >= 0 and end > start:
    agents = '''class AgentsPage extends StatefulWidget {
  const AgentsPage({super.key});
  @override
  State<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends State<AgentsPage> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = loadAgents();
  }

  Future<List<Map<String, dynamic>>> loadAgents() async {
    final rows = await db
        .from('profiles')
        .select('id,full_name,email,phone,state,available,password_set,agent_approval_status')
        .eq('role', 'agent')
        .order('full_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  void refresh() {
    setState(() => future = loadAgents());
  }

  Future<void> setApproval(String id, String status) async {
    try {
      await db.rpc('tz_set_agent_approval', params: {
        'p_agent': id,
        'p_status': status,
      });
      refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> setActive(String id, bool active) async {
    try {
      await db.rpc('tz_set_agent_active', params: {
        'p_agent': id,
        'p_active': active,
      });
      refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget agentCard(Map<String, dynamic> a) {
    final status = '${a['agent_approval_status'] ?? 'approved'}';
    final fullName = '${a['full_name'] ?? 'Unnamed agent'}';
    final email = '${a['email'] ?? ''}';
    final phone = '${a['phone'] ?? ''}';
    final state = '${a['state'] ?? 'State not set'}';
    final active = a['available'] == true;
    final initial = fullName.trim().isEmpty ? 'A' : fullName.trim()[0].toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(initial)),
              title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('$email\\n$phone • $state'),
              isThreeLine: true,
              trailing: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: status == 'approved' ? green : (status == 'pending' ? orange : red),
                ),
              ),
            ),
            if (status == 'pending')
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => setApproval('${a['id']}', 'approved'),
                      icon: const Icon(Icons.check),
                      label: const Text('APPROVE'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setApproval('${a['id']}', 'rejected'),
                      icon: const Icon(Icons.close),
                      label: const Text('REJECT'),
                    ),
                  ),
                ],
              ),
            if (status == 'approved')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setActive('${a['id']}', !active),
                  icon: Icon(active ? Icons.person_remove : Icons.person_add),
                  label: Text(active ? 'REMOVE AGENT' : 'RESTORE AGENT'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Agents error: ${snap.error}'));
        }

        final rows = snap.data ?? <Map<String, dynamic>>[];
        final pending = rows.where((a) => a['agent_approval_status'] == 'pending').length;

        return RefreshIndicator(
          onRefresh: () async {
            refresh();
            await future;
          },
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Agents', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy)),
                  if (pending > 0)
                    Chip(
                      label: Text('$pending pending'),
                      avatar: const Icon(Icons.hourglass_top, size: 18),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Agents register themselves. Approve them here before they can use TZ.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              for (final a in rows) agentCard(a),
            ],
          ),
        );
      },
    );
  }
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
  bool hide = true;

  Future<void> register() async {
    final n = name.text.trim();
    final e = email.text.trim().toLowerCase();
    final p = phone.text.trim();
    final st = state.text.trim();

    if (n.isEmpty || !e.contains('@') || p.isEmpty || st.isEmpty || password.text.length < 8 || password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete all fields. Passwords must match and contain at least 8 characters.')),
      );
      return;
    }

    setState(() => busy = true);
    try {
      final res = await db.auth.signUp(
        email: e,
        password: password.text,
        data: {
          'full_name': n,
          'phone': p,
          'state': st,
          'registration_type': 'agent',
        },
      );
      await db.auth.signOut();
      if (!mounted) return;

      final needsEmailConfirmation = res.session == null;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Registration submitted'),
          content: Text(
            needsEmailConfirmation
                ? 'Your registration has been submitted. An administrator must approve your registration before you can sign in.'
                : 'Your registration has been submitted. An administrator must approve your registration before you can sign in.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register as Agent')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Logo(size: 105),
          const SizedBox(height: 10),
          const Text('Join Temz Store as an Agent', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: navy)),
          const SizedBox(height: 6),
          const Text('Submit your details. A Temz Store administrator will review and approve your registration.'),
          const SizedBox(height: 20),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 12),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: 12),
          TextField(controller: state, decoration: const InputDecoration(labelText: 'State', prefixIcon: Icon(Icons.location_on_outlined))),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: hide, decoration: InputDecoration(labelText: 'Create password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility : Icons.visibility_off)))),
          const SizedBox(height: 12),
          TextField(controller: confirm, obscureText: hide, decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.verified_user_outlined))),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: busy ? null : register,
              child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SUBMIT REGISTRATION'),
            ),
          ),
        ],
      ),
    );
  }
}

'''
    s = s[:start] + agents + s[end:]

p.write_text(s, encoding='utf-8')
print('Applied corrected self-registration and approval workflow.')
