import { createClient } from 'jsr:@supabase/supabase-js@2'

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-tz-webhook-secret' }

type IncomingItem = { name?: string; product?: string; quantity?: number | string; qty?: number | string }

function itemsFromPayload(body: Record<string, unknown>): IncomingItem[] {
  if (Array.isArray(body.products)) return body.products as IncomingItem[]
  const items: IncomingItem[] = []
  if (body.product || body.product_name) items.push({ name: String(body.product ?? body.product_name), quantity: body.quantity ?? 1 })
  if (Array.isArray(body.cross_sells)) items.push(...(body.cross_sells as IncomingItem[]))
  if (body.cross_sell_product) items.push({ name: String(body.cross_sell_product), quantity: body.cross_sell_quantity ?? 1 })
  return items
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  const secret = Deno.env.get('TZ_WEBHOOK_SECRET')
  if (!secret || req.headers.get('x-tz-webhook-secret') !== secret) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } })
  }

  try {
    const body = await req.json() as Record<string, unknown>
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    const rawItems = itemsFromPayload(body)
    if (!rawItems.length) throw new Error('No product items supplied')

    const names = rawItems.map((x) => String(x.name ?? x.product ?? '').trim()).filter(Boolean)
    const { data: products, error: productError } = await admin.from('products').select('id,name,selling_price').in('name', names)
    if (productError) throw productError
    const byName = new Map((products ?? []).map((p) => [p.name.toLowerCase(), p]))

    const lineItems = rawItems.map((x) => {
      const name = String(x.name ?? x.product ?? '').trim()
      const p = byName.get(name.toLowerCase())
      if (!p) throw new Error(`Product not found: ${name}`)
      const quantity = Math.max(1, Number(x.quantity ?? x.qty ?? 1))
      return { product_id: p.id, quantity, unit_price: Number(p.selling_price) }
    })
    const total = lineItems.reduce((sum, x) => sum + x.quantity * x.unit_price, 0)

    const { data: orderNumber, error: numberError } = await admin.rpc('tz_next_order_number')
    if (numberError) throw numberError

    const { data: order, error: orderError } = await admin.from('orders').insert({
      order_number: orderNumber,
      customer_name: String(body.customer_name ?? body.name ?? ''),
      customer_phone: String(body.customer_phone ?? body.phone ?? ''),
      customer_email: body.customer_email ?? body.email ?? null,
      state: String(body.state ?? ''),
      city: String(body.city ?? ''),
      delivery_address: String(body.delivery_address ?? body.address ?? ''),
      total_amount: total,
      created_from: 'wordpress',
      status: 'New Order'
    }).select('id,order_number').single()
    if (orderError) throw orderError

    const { error: itemError } = await admin.from('order_items').insert(lineItems.map((x) => ({ ...x, order_id: order.id, line_total: undefined })))
    if (itemError) throw itemError

    // Notify every admin account currently present in profiles.
    const { data: admins } = await admin.from('profiles').select('id').eq('role', 'admin')
    if (admins?.length) {
      await admin.from('notifications').insert(admins.map((a) => ({ user_id: a.id, title: 'New order received', body: `${order.order_number} is ready for assignment.`, type: 'new_order', order_id: order.id })))
    }

    return new Response(JSON.stringify({ ok: true, order_id: order.id, order_number: order.order_number, total }), { headers: { ...cors, 'Content-Type': 'application/json' } })
  } catch (error) {
    console.error(error)
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Webhook failed' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } })
  }
})
