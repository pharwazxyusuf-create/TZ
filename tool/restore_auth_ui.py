from pathlib import Path
import re

p=Path('lib/tz_build.dart')
s=p.read_text()
marker='class ProfileGate extends StatefulWidget {'
if marker not in s:
    raise SystemExit('ProfileGate marker not found')

block=r'''
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController();
  bool busy = false;
  Future<void> send() async {
    final value = email.text.trim().toLowerCase();
    if (value.isEmpty) return;
    setState(() => busy = true);
    try {
      await db.auth.resetPasswordForEmail(value, redirectTo: 'tz://auth-callback/');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent. Check your inbox.')));
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send the reset email. Check your internet connection and try again.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Forgot Password')),
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Column(children: [
        const Logo(size: 120),
        const SizedBox(height: 18),
        const Text('Reset your password', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 8),
        const Text('Enter your TZ account email and we will send you a reset link.', textAlign: TextAlign.center),
        const SizedBox(height: 22),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : send, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SEND RESET LINK'))),
      ]),
    ))),
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
  bool hide = true;
  Future<void> register() async {
    if (name.text.trim().isEmpty || email.text.trim().isEmpty || phone.text.trim().isEmpty || stateName.text.trim().isEmpty || password.text.length < 8 || password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete all fields and use matching passwords of at least 8 characters.')));
      return;
    }
    setState(() => busy = true);
    try {
      final result = await db.auth.signUp(
        email: email.text.trim().toLowerCase(),
        password: password.text,
        data: {'registration_type': 'agent', 'full_name': name.text.trim(), 'phone': phone.text.trim(), 'state': stateName.text.trim()},
      );
      await db.auth.signOut();
      if (!mounted) return;
      final pending = result.session == null;
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Registration submitted'),
        content: Text(pending ? 'Your agent registration has been submitted. Check your email if confirmation is required, then wait for Temz Store admin approval.' : 'Your registration has been submitted and is awaiting Temz Store admin approval.'),
        actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('DONE'))],
      ));
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration failed. Check your internet connection and try again.')));
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
      TextField(controller: password, obscureText: hide, decoration: InputDecoration(labelText: 'Password', suffixIcon: IconButton(onPressed: () => setState(() => hide=!hide), icon: Icon(hide ? Icons.visibility : Icons.visibility_off)))),
      const SizedBox(height: 12),
      TextField(controller: confirm, obscureText: hide, decoration: const InputDecoration(labelText: 'Confirm password')),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : register, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('SUBMIT REGISTRATION'))),
    ])),),
  );
}

'''
if 'class ForgotPasswordPage extends StatefulWidget' not in s:
    s=s.replace(marker, block+marker,1)

needle="SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : login, child: busy ? const CircularProgressIndicator() : const Text('SIGN IN'))),"
replacement=needle+"\n                          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())), child: const Text('Forgot Password?'))),\n                          SizedBox(width: double.infinity, height: 46, child: OutlinedButton.icon(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentRegistrationPage())), icon: const Icon(Icons.person_add_alt_1), label: const Text('REGISTER AS AGENT'))),"
if needle in s and "child: const Text('Forgot Password?')" not in s:
    s=s.replace(needle,replacement,1)

s=s.replace("const Text('TEMZ STORE OPERATIONS', style: TextStyle(letterSpacing: 2, color: blue, fontWeight: FontWeight.w800)),","const Text('TEMZ STORE OPERATIONS', style: TextStyle(letterSpacing: 2, color: blue, fontWeight: FontWeight.w800)),\n                  const SizedBox(height: 5),\n                  const Text('ADMIN / AGENT LOGIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: navy)),",1)

start=s.find('class AgentsPage extends StatelessWidget {')
end=s.find('class StockPage extends StatelessWidget {', start)
if start==-1 or end==-1:
    raise SystemExit('AgentsPage/StockPage markers not found')
agent_page=r'''class AgentsPage extends StatefulWidget {
  const AgentsPage({super.key});
  @override
  State<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends State<AgentsPage> {
  bool busy = false;
  Future<List<Map<String,dynamic>>> load() async {
    final rows = await db.from('profiles').select('id,full_name,phone,state,available,agent_approval_status').eq('role','agent').order('full_name');
    return List<Map<String,dynamic>>.from(rows);
  }
  Future<void> approve(String id, String status) async {
    setState(() => busy = true);
    try {
      await db.rpc('tz_set_agent_approval', params: {'p_agent': id, 'p_status': status});
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => busy=false); }
  }
  Future<void> active(String id, bool value) async {
    setState(() => busy=true);
    try { await db.rpc('tz_set_agent_active', params: {'p_agent': id, 'p_active': value}); if (mounted) setState(() {}); }
    catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    finally { if(mounted) setState(() => busy=false); }
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String,dynamic>>>(future: load(), builder: (context,snap) {
    if (!snap.hasData) return const Center(child:CircularProgressIndicator());
    final rows=snap.data!;
    return RefreshIndicator(onRefresh: () async { if (mounted) setState(() {}); }, child: ListView(padding:const EdgeInsets.all(14), children:[
      const Text('Agents',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:navy)),
      const SizedBox(height:6),
      Text('${rows.where((x)=>x['agent_approval_status']=='pending').length} pending approval',style:const TextStyle(fontWeight:FontWeight.w700)),
      const SizedBox(height:12),
      for(final a in rows) Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${a['full_name'] ?? 'Agent'}',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)),
        Text('${a['phone'] ?? ''} • ${a['state'] ?? ''}'),
        Text('Approval: ${a['agent_approval_status'] ?? 'approved'} • ${a['available']==true ? 'Active' : 'Inactive'}'),
        const SizedBox(height:8),
        Wrap(spacing:8,runSpacing:8,children:[
          if(a['agent_approval_status']=='pending') FilledButton(onPressed:busy?null:()=>approve('${a['id']}','approved'),child:const Text('APPROVE')),
          if(a['agent_approval_status']=='pending') OutlinedButton(onPressed:busy?null:()=>approve('${a['id']}','rejected'),child:const Text('REJECT')),
          if(a['agent_approval_status']=='approved') OutlinedButton(onPressed:busy?null:()=>active('${a['id']}',a['available']!=true),child:Text(a['available']==true?'REMOVE':'RESTORE')),
        ])
      ])))
    ]));
  });
}

'''
s=s[:start]+agent_page+s[end:]
p.write_text(s)
print('Auth UI + agent approval controls restored.')
