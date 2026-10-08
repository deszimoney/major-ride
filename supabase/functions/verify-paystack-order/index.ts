import { createClient } from "npm:@supabase/supabase-js@2";

const jsonHeaders = { "content-type": "application/json; charset=utf-8" };

function response(status: number, body: Record<string, unknown>, origin?: string) {
  const headers = new Headers(jsonHeaders);
  if (origin) {
    headers.set("access-control-allow-origin", origin);
    headers.set("vary", "Origin");
  }
  return new Response(JSON.stringify(body), { status, headers });
}

function allowedOrigins(): string[] {
  return (Deno.env.get("SITE_ORIGINS") ?? "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
}

function parseItems(value: unknown): { id: string; quantity: number }[] | null {
  if (!Array.isArray(value) || value.length < 1 || value.length > 50) return null;
  const items: { id: string; quantity: number }[] = [];
  let totalQuantity = 0;
  for (const item of value) {
    if (
      !item ||
      typeof item.id !== "string" ||
      !/^[A-Za-z0-9_-]{1,80}$/.test(item.id) ||
      !Number.isInteger(item.quantity) ||
      item.quantity < 1 ||
      item.quantity > 20
    ) {
      return null;
    }
    totalQuantity += item.quantity;
    if (totalQuantity > 100) return null;
    items.push({ id: item.id, quantity: item.quantity });
  }
  return items;
}

Deno.serve(async (request) => {
  const origin = request.headers.get("origin") ?? "";
  const origins = allowedOrigins();
  if (!origins.length || !origins.includes(origin)) {
    return response(403, { error: "Origin is not allowed." });
  }

  const corsHeaders = new Headers({
    ...jsonHeaders,
    "access-control-allow-origin": origin,
    "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
    "access-control-allow-methods": "POST, OPTIONS",
    "vary": "Origin",
  });
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed." }), {
      status: 405,
      headers: corsHeaders,
    });
  }
  if (!request.headers.get("content-type")?.toLowerCase().startsWith("application/json")) {
    return new Response(JSON.stringify({ error: "JSON request body required." }), {
      status: 415,
      headers: corsHeaders,
    });
  }

  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (contentLength > 16_384) {
    return new Response(JSON.stringify({ error: "Request is too large." }), {
      status: 413,
      headers: corsHeaders,
    });
  }

  try {
    const rawBody = await request.text();
    if (rawBody.length > 16_384) {
      return new Response(JSON.stringify({ error: "Request is too large." }), {
        status: 413,
        headers: corsHeaders,
      });
    }

    const body = JSON.parse(rawBody);
    const action = body?.action ?? "verify";
    const reference = body?.reference;
    const items = parseItems(body?.items);
    const deliveryMethod = body?.deliveryMethod;
    const deliveryLocation = typeof body?.deliveryLocation === "string"
      ? body.deliveryLocation.trim()
      : "";

    const authorization = request.headers.get("authorization");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const paystackSecret = Deno.env.get("PAYSTACK_SECRET_KEY");
    if (!authorization?.startsWith("Bearer ") || !supabaseUrl || !anonKey ||
      !serviceRoleKey || !paystackSecret) {
      return new Response(JSON.stringify({ error: "Payment verification is not configured." }), {
        status: 503,
        headers: corsHeaders,
      });
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    const user = userData.user;
    if (userError || !user?.id || !user.email) {
      return new Response(JSON.stringify({ error: "A valid signed-in account is required." }), {
        status: 401,
        headers: corsHeaders,
      });
    }

    if (action === "healthcheck") {
      return new Response(JSON.stringify({ ready: true }), {
        status: 200,
        headers: corsHeaders,
      });
    }
    if (action !== "verify") {
      return new Response(JSON.stringify({ error: "Invalid request action." }), {
        status: 400,
        headers: corsHeaders,
      });
    }
    if (
      typeof reference !== "string" ||
      !/^[A-Za-z0-9_-]{1,100}$/.test(reference) ||
      !items ||
      !["delivery", "pickup"].includes(deliveryMethod) ||
      deliveryLocation.length > 300 ||
      (deliveryMethod === "delivery" && deliveryLocation.length < 4)
    ) {
      return new Response(JSON.stringify({ error: "Invalid order details." }), {
        status: 400,
        headers: corsHeaders,
      });
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: products, error: productError } = await adminClient
      .from("products")
      .select("id, name, price")
      .in("id", [...new Set(items.map((item) => item.id))]);
    if (productError) {
      console.error("Could not load catalog for payment verification.", productError);
      return new Response(JSON.stringify({ error: "Unable to verify the order right now." }), {
        status: 503,
        headers: corsHeaders,
      });
    }

    const productsById = new Map((products ?? []).map((product) => [product.id, product]));
    if (items.some((item) => !productsById.has(item.id))) {
      return new Response(JSON.stringify({ error: "The cart contains an unavailable product." }), {
        status: 400,
        headers: corsHeaders,
      });
    }

    const orderItems = items.map((item) => {
      const product = productsById.get(item.id)!;
      const unitAmount = Math.round(Number(product.price) * 100);
      return {
        id: product.id,
        name: product.name,
        price: unitAmount / 100,
        quantity: item.quantity,
      };
    });
    const subtotal = orderItems.reduce(
      (sum, item) => sum + Math.round(item.price * 100) * item.quantity,
      0,
    );
    const serviceFee = deliveryMethod === "pickup" ? 1500 : 4000;
    const expectedAmount = subtotal + serviceFee;
    if (!Number.isSafeInteger(expectedAmount) || expectedAmount <= 0) {
      return new Response(JSON.stringify({ error: "Invalid order total." }), {
        status: 400,
        headers: corsHeaders,
      });
    }

    const paystackResponse = await fetch(
      `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
      {
        headers: { authorization: `Bearer ${paystackSecret}` },
        signal: AbortSignal.timeout(10_000),
      },
    );
    if (!paystackResponse.ok) {
      return new Response(JSON.stringify({ error: "Paystack could not verify this payment." }), {
        status: 502,
        headers: corsHeaders,
      });
    }

    const paystackResult = await paystackResponse.json();
    const transaction = paystackResult?.data;
    if (
      paystackResult?.status !== true ||
      transaction?.status !== "success" ||
      transaction?.reference !== reference ||
      transaction?.currency !== "GHS" ||
      transaction?.amount !== expectedAmount ||
      transaction?.customer?.email?.toLowerCase() !== user.email.toLowerCase()
    ) {
      return new Response(JSON.stringify({ error: "Payment details did not match this order." }), {
        status: 402,
        headers: corsHeaders,
      });
    }

    const { data: existingOrder, error: existingError } = await adminClient
      .from("orders")
      .select("*")
      .eq("payment_reference", reference)
      .maybeSingle();
    if (existingError) {
      console.error("Could not check payment reference.", existingError);
      return new Response(JSON.stringify({ error: "Unable to save the verified order." }), {
        status: 503,
        headers: corsHeaders,
      });
    }
    if (existingOrder) {
      if (
        existingOrder.user_id !== user.id ||
        !existingOrder.payment_verified_at ||
        existingOrder.payment_status !== "completed"
      ) {
        return new Response(JSON.stringify({ error: "Payment reference is already in use." }), {
          status: 409,
          headers: corsHeaders,
        });
      }
      return new Response(JSON.stringify({ order: existingOrder }), {
        status: 200,
        headers: corsHeaders,
      });
    }

    const order = {
      id: crypto.randomUUID(),
      user_id: user.id,
      user_name: user.user_metadata?.name || user.email.split("@")[0],
      user_email: user.email,
      items: orderItems,
      subtotal: subtotal / 100,
      service_fee: serviceFee / 100,
      total: expectedAmount / 100,
      payment_status: "completed",
      payment_provider: "paystack",
      payment_reference: reference,
      payment_verified_at: new Date().toISOString(),
      paid_at: transaction.paid_at ?? new Date().toISOString(),
      delivery_method: deliveryMethod,
      delivery_location: deliveryMethod === "pickup" ? null : deliveryLocation,
      delivery_confirmed: false,
      delivered_at: null,
    };

    const { data: savedOrder, error: saveError } = await adminClient
      .from("orders")
      .insert(order)
      .select("*")
      .single();
    if (saveError) {
      console.error("Could not save verified order.", saveError);
      return new Response(JSON.stringify({ error: "Payment was verified but the order could not be saved. Contact support with your payment reference." }), {
        status: 503,
        headers: corsHeaders,
      });
    }

    return new Response(JSON.stringify({ order: savedOrder }), {
      status: 201,
      headers: corsHeaders,
    });
  } catch (error) {
    console.error("Unexpected payment verification failure.", error);
    return new Response(JSON.stringify({ error: "Unable to verify the payment right now." }), {
      status: 500,
      headers: corsHeaders,
    });
  }
});
