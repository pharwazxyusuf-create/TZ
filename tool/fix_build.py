from pathlib import Path

p = Path('lib/tz_build.dart')
s = p.read_text(encoding='utf-8')

# Remove the fragile one-line StockPage implementation and replace it with
# a deliberately multiline implementation that is easy for Dart to parse.
marker = 'class StockPage extends StatelessWidget {'
if marker in s:
    prefix = s.split(marker, 1)[0]
    replacement = r'''class StockPage extends StatelessWidget {
  const StockPage({super.key});

  @override
  Widget build(BuildContext context) {
    final future = db
        .from('products')
        .select('id,name,price,central_stock')
        .order('name');

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Stock error: ${snapshot.error}'));
        }

        final rows = snapshot.data ?? <Map<String, dynamic>>[];
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const Text(
              'Central Stock',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: navy),
            ),
            const SizedBox(height: 10),
            for (final product in rows)
              Card(
                child: ListTile(
                  title: Text(
                    '${product['name'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('Selling price: ₦${product['price'] ?? 0}'),
                  trailing: Text(
                    '${product['central_stock'] ?? 0}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
'''
    s = prefix + replacement

# Use the current Supabase publishable-key parameter instead of the deprecated alias.
s = s.replace('Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey)', 'Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey)')
p.write_text(s, encoding='utf-8')
