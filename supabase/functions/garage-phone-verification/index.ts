import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const twilioAccountSid = Deno.env.get('TWILIO_ACCOUNT_SID')!;
const twilioAuthToken = Deno.env.get('TWILIO_AUTH_TOKEN')!;
const twilioVerifyServiceSid = Deno.env.get('TWILIO_VERIFY_SERVICE_SID')!;

const admin = createClient(supabaseUrl, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

  try {
    const authHeader = request.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return json({ error: 'authentication_required' }, 401);
    }
    const token = authHeader.slice('Bearer '.length);
    const { data: userResult, error: userError } = await admin.auth.getUser(token);
    const user = userResult.user;
    if (userError || !user || !user.email_confirmed_at) {
      return json({ error: 'confirmed_account_required' }, 403);
    }

    const { data: profile, error: profileError } = await admin
      .from('profiles')
      .select('account_type')
      .eq('id', user.id)
      .maybeSingle();
    if (profileError || profile?.account_type !== 'garage_owner') {
      return json({ error: 'garage_owner_account_required' }, 403);
    }

    const body = await request.json();
    if (body.action === 'send_code') {
      return await sendCode(user.id, body.phone);
    }
    if (body.action === 'verify_code') {
      return await verifyCode(user.id, body.challengeId, body.code);
    }
    if (body.action === 'record_presence') {
      return await recordPresence(user.id, body);
    }
    return json({ error: 'invalid_action' }, 400);
  } catch (error) {
    console.error('garage-phone-verification failed', error);
    return json({ error: 'verification_unavailable' }, 500);
  }
});

async function sendCode(ownerId: string, rawPhone: unknown): Promise<Response> {
  const phone = normalizeE164(rawPhone);
  if (!phone) return json({ error: 'phone_must_be_e164' }, 400);

  const now = Date.now();
  const recent = new Date(now - 60_000).toISOString();
  const hourAgo = new Date(now - 60 * 60_000).toISOString();
  const [recentOwner, hourlyOwner, hourlyPhone] = await Promise.all([
      admin.from('garage_phone_verification_challenges')
        .select('id', { count: 'exact', head: true })
        .eq('owner_id', ownerId)
        .gte('created_at', recent),
      admin.from('garage_phone_verification_challenges')
        .select('id', { count: 'exact', head: true })
        .eq('owner_id', ownerId)
        .gte('created_at', hourAgo),
      admin.from('garage_phone_verification_challenges')
        .select('id', { count: 'exact', head: true })
        .eq('phone_e164', phone)
        .gte('created_at', hourAgo),
    ]);
  if (recentOwner.error || hourlyOwner.error || hourlyPhone.error) {
    throw new Error('rate_limit_lookup_failed');
  }
  if ((recentOwner.count ?? 0) > 0) {
    return json({ error: 'wait_before_resending' }, 429);
  }
  if ((hourlyOwner.count ?? 0) >= 3 || (hourlyPhone.count ?? 0) >= 3) {
    return json({ error: 'hourly_limit_reached' }, 429);
  }

  const { data: challenge, error: insertError } = await admin
    .from('garage_phone_verification_challenges')
    .insert({ owner_id: ownerId, phone_e164: phone })
    .select('id')
    .single();
  if (insertError || !challenge) throw new Error('challenge_create_failed');

  const response = await twilioRequest('Verifications', {
    To: phone,
    Channel: 'sms',
  });
  if (!response.ok) {
    console.error('Twilio Verify send failed', response.status);
    return json({ error: 'sms_delivery_failed' }, 502);
  }

  const verification = await response.json();
  const { error: updateError } = await admin
    .from('garage_phone_verification_challenges')
    .update({ provider_sid: verification.sid })
    .eq('id', challenge.id);
  if (updateError) throw new Error('challenge_update_failed');
  return json({ challengeId: challenge.id, expiresInSeconds: 600 }, 200);
}

async function recordPresence(ownerId: string, body: Record<string, unknown>) {
  if (typeof body.garageId !== 'string' ||
      typeof body.latitude !== 'number' ||
      typeof body.longitude !== 'number' ||
      typeof body.accuracyMeters !== 'number' ||
      typeof body.locationIsMocked !== 'boolean') {
    return json({ error: 'invalid_presence_data' }, 400);
  }

  const { data, error } = await admin.rpc('record_garage_on_site_presence', {
    p_owner_id: ownerId,
    p_garage_id: body.garageId,
    p_latitude: body.latitude,
    p_longitude: body.longitude,
    p_accuracy_meters: body.accuracyMeters,
    p_location_is_mocked: body.locationIsMocked,
  });
  if (error) throw new Error('presence_check_failed');
  const result = Array.isArray(data) ? data[0] : data;
  if (result?.verified !== true) {
    return json({ error: 'on_site_presence_failed' }, 422);
  }
  return json({
    verified: true,
    distanceMeters: result.distance_meters,
  }, 200);
}

async function verifyCode(
  ownerId: string,
  challengeId: unknown,
  rawCode: unknown,
): Promise<Response> {
  if (typeof challengeId !== 'string' ||
      !/^[0-9a-f-]{36}$/i.test(challengeId) ||
      typeof rawCode !== 'string' ||
      !/^\d{4,10}$/.test(rawCode)) {
    return json({ error: 'invalid_code_or_challenge' }, 400);
  }

  const { data: challenge, error } = await admin
    .from('garage_phone_verification_challenges')
    .select('id,phone_e164,provider_sid,expires_at,verified_at,consumed_at')
    .eq('id', challengeId)
    .eq('owner_id', ownerId)
    .maybeSingle();
  if (error || !challenge) return json({ error: 'challenge_not_found' }, 404);
  if (challenge.consumed_at || new Date(challenge.expires_at).getTime() <= Date.now()) {
    return json({ error: 'challenge_expired' }, 410);
  }
  if (challenge.verified_at) return json({ verified: true }, 200);
  if (!challenge.provider_sid) return json({ error: 'challenge_not_ready' }, 409);

  const response = await twilioRequest('VerificationCheck', {
    To: challenge.phone_e164,
    Code: rawCode,
  });
  if (!response.ok) {
    if (response.status === 404 || response.status === 400) {
      return json({ error: 'invalid_code' }, 400);
    }
    console.error('Twilio Verify check failed', response.status);
    return json({ error: 'verification_provider_unavailable' }, 502);
  }

  const result = await response.json();
  if (result.status !== 'approved') return json({ error: 'invalid_code' }, 400);
  const verifiedAt = new Date().toISOString();
  const { error: updateError } = await admin
    .from('garage_phone_verification_challenges')
    .update({ verified_at: verifiedAt })
    .eq('id', challenge.id)
    .is('verified_at', null)
    .is('consumed_at', null);
  if (updateError) throw new Error('challenge_verify_update_failed');
  return json({ verified: true, phone: challenge.phone_e164 }, 200);
}

function normalizeE164(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const phone = value.trim().replace(/[\s().-]/g, '');
  return /^\+[1-9]\d{7,14}$/.test(phone) ? phone : null;
}

function twilioRequest(
  endpoint: 'Verifications' | 'VerificationCheck',
  values: Record<string, string>,
): Promise<Response> {
  if (!twilioAccountSid || !twilioAuthToken || !twilioVerifyServiceSid) {
    throw new Error('Twilio Verify secrets are missing');
  }
  const form = new URLSearchParams(values);
  const credentials = btoa(`${twilioAccountSid}:${twilioAuthToken}`);
  return fetch(
    `https://verify.twilio.com/v2/Services/${twilioVerifyServiceSid}/${endpoint}`,
    {
      method: 'POST',
      headers: {
        Authorization: `Basic ${credentials}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: form,
    },
  );
}

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
