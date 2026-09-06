import { createClient } from 'jsr:@supabase/supabase-js@2'

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 })
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  const cutoff = new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString()

  const { data: orders, error } = await admin
    .from('orders')
    .select('id,order_number,status,assigned_agent_id,last_agent_update_at')
    .not('assigned_agent_id', 'is', null)
    .in('status', ['Awaiting Agent Acceptance','Accepted','Out for Delivery','Customer Not Available','Unable to Meet Up','Customer Chose Another Day'])
    .or(`last_agent_update_at.is.null,last_agent_update_at.lt.${cutoff}`)

  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 })

  let sent = 0
  for (const order of orders ?? []) {
    // Prevent duplicate reminder rows inside the same 3-hour window.
    const { data: recent } = await admin.from('notifications')
      .select('id').eq('user_id', order.assigned_agent_id)
      .eq('order_id', order.id).eq('type', 'reminder')
      .gte('created_at', cutoff).limit(1)
    if (recent?.length) continue

    await admin.from('notifications').insert({
      user_id: order.assigned_agent_id,
      title: 'TZ order reminder',
      body: `${order.order_number} still needs a final delivery update.`,
      type: 'reminder',
      order_id: order.id
    })
    sent++
  }

  return new Response(JSON.stringify({ ok: true, reminders: sent }), { headers: { 'Content-Type': 'application/json' } })
})
