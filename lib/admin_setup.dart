import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _navy = Color(0xFF071B3A);
const _blue = Color(0xFF1264E8);

const _adminEmails = {
  'pharwazxyusuf@gmail.com',
  'mytemzbusiness@gmail.com',
  'omolaratemilade567@gmail.com',
};

class AdminSetupPage extends StatefulWidget {
  const AdminSetupPage({super.key});
  @override
  State<AdminSetupPage> createState() => _AdminSetupPageState();
}

class _AdminSetupPageState extends State<AdminSetupPage> {
  final email = TextEditingController();
  final name = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  bool hidden = true;

  Future<void> create() async {
    final e = email.text.trim().toLowerCase();
    if (!_adminEmails.contains(e)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This email is not on the Temz Store administrator list.')));
      return;
    }
    if (name.text.trim().isEmpty || password.text.length < 8 || password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your name and a matching password of at least 8 characters.')));
      return;
    }
    setState(() => busy = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: e,
        password: password.text,
        data: {'full_name': name.text.trim()},
      );
      if (!mounted) return;
      if (res.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created. Check your email to confirm the account, then sign in.')));
        Navigator.pop(context);
      } else {
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to reach Temz Store server. Check your internet connection and try again.\n$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('First-time Admin Setup')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text('Create your TZ administrator account', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _navy)),
        const SizedBox(height: 8),
        const Text('Use one of the three approved Temz Store administrator emails.'),
        const SizedBox(height: 20),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 14),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Administrator email', prefixIcon: Icon(Icons.email_outlined))),
        const SizedBox(height: 14),
        TextField(controller: password, obscureText: hidden, decoration: InputDecoration(labelText: 'Password (8+ characters)', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility : Icons.visibility_off)))),
        const SizedBox(height: 14),
        TextField(controller: confirm, obscureText: hidden, decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.verified_user_outlined))),
        const SizedBox(height: 22),
        SizedBox(height: 52, child: FilledButton(onPressed: busy ? null : create, child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('CREATE ADMIN ACCOUNT'))),
        const SizedBox(height: 12),
        const Text('Your email may need to be confirmed before you can sign in.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ],
    ),
  );
}
