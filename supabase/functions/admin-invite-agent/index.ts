import { createClient } from 'jsr:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json',
}

const redirectTo = 'tz://auth-callback/'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return new Response(JSON.stringify({ error: 'POST required' }), { status: 405, headers: cors })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader?.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'Authentication required' }), { status: 401, headers: cors })
    }

    const url = Deno.env.get('SUPABASE_URL')!
    const publishableKey = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY')!
    const secretKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY')!

    const userClient = createClient(url, publishableKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    })
    const { data: { user }, error: userError } = await userClient.auth.getUser()
    if (userError || !user) throw new Error('Invalid session')

    const admin = createClient(url, secretKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const { data: caller, error: callerError } = await admin.from('profiles').select('id,role').eq('id', user.id).maybeSingle()
    if (callerError) throw callerError
    if (caller?.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Admin access required' }), { status: 403, headers: cors })
    }

    const body = await req.json() as Record<string, unknown>
    const email = String(body.email ?? '').trim().toLowerCase()
    const fullName = String(body.full_name ?? '').trim()
    const phone = String(body.phone ?? '').trim()
    const state = String(body.state ?? '').trim()

    if (!email || !email.includes('@')) throw new Error('A valid agent email is required')
    if (!fullName) throw new Error('Agent name is required')

    const metadata = { full_name: fullName, role: 'agent', phone, state, must_set_password: true }
    let linkData: any = null
    let linkError: any = null

    // New agents use a one-time invite link. If this email already has an Auth account,
    // fall back to a one-time magic link so the admin can refresh the agent's access link.
    ({ data: linkData, error: linkError } = await admin.auth.admin.generateLink({
      type: 'invite',
      email,
      options: { redirectTo, data: metadata },
    }))

    if (linkError) {
      ({ data: linkData, error: linkError } = await admin.auth.admin.generateLink({
        type: 'magiclink',
        email,
        options: { redirectTo, data: metadata },
      }))
      if (linkError) throw linkError
    }

    const agentUser = linkData?.user
    if (!agentUser) throw new Error('Agent account could not be created or found')

    // Keep the Auth metadata current even when the magic-link fallback was used.
    const { error: authUpdateError } = await admin.auth.admin.updateUserById(agentUser.id, { user_metadata: metadata })
    if (authUpdateError) throw authUpdateError

    const { error: profileError } = await admin.from('profiles').upsert({
      id: agentUser.id,
      full_name: fullName,
      email,
      phone: phone || null,
      role: 'agent',
      state: state || null,
      available: true,
      password_set: false,
    }, { onConflict: 'id' })
    if (profileError) throw profileError

    await admin.from('audit_logs').insert({
      actor_id: user.id,
      action: 'agent_access_link_created',
      entity_type: 'profile',
      entity_id: agentUser.id,
      details: { email, full_name: fullName, state },
    })

    const actionLink = linkData?.properties?.action_link ?? linkData?.properties?.actionLink
    if (!actionLink) throw new Error('Supabase did not return an access link')

    return new Response(JSON.stringify({
      ok: true,
      agent_id: agentUser.id,
      email,
      action_link: actionLink,
      redirect_to: redirectTo,
      message: 'Agent access link created. Share it privately. It is time-limited and the agent will be asked to set a personal password.',
    }), { status: 200, headers: cors })
  } catch (error) {
    console.error(error)
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Agent invitation failed' }), { status: 400, headers: cors })
  }
})
