import { createClient } from 'jsr:@supabase/supabase-js@2'

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const client = createClient(supabaseUrl, serviceKey)

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    const token = authHeader.replace('Bearer ', '')
    const { data: userData, error: userError } = await client.auth.getUser(token)
    if (userError || !userData.user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

    const { data: caller } = await client.from('profiles').select('role').eq('id', userData.user.id).maybeSingle()
    if (caller?.role !== 'admin') return new Response(JSON.stringify({ error: 'Admin access required' }), { status: 403 })

    const body = await req.json()
    const email = String(body.email ?? '').trim().toLowerCase()
    const fullName = String(body.full_name ?? '').trim()
    const role = body.role === 'admin' ? 'admin' : 'agent'
    if (!email) return new Response(JSON.stringify({ error: 'Email is required' }), { status: 400 })

    const { data: invited, error: inviteError } = await client.auth.admin.inviteUserByEmail(email, {
      data: { full_name: fullName },
    })
    if (inviteError) throw inviteError

    if (invited.user) {
      await client.from('profiles').update({ full_name: fullName, role }).eq('id', invited.user.id)
    }

    return new Response(JSON.stringify({ ok: true, user_id: invited.user?.id }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : 'Invitation failed' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
