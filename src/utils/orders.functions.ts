import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { createClient } from "@supabase/supabase-js";
import type { Database } from "@/integrations/supabase/types";

function getAnonClient() {
  const url = process.env.SUPABASE_URL || import.meta.env.VITE_SUPABASE_URL;
  const key = process.env.SUPABASE_PUBLISHABLE_KEY || import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error("Missing Supabase environment variables");
  return createClient<Database>(url, key, {
    auth: { storage: undefined, persistSession: false, autoRefreshToken: false },
  });
}

const cartItemSchema = z.object({
  productId: z.string().uuid(),
  variantId: z.string().uuid(),
  name: z.string().min(1).max(255),
  size: z.string().min(1).max(50),
  price: z.number().int().positive(),
  quantity: z.number().int().min(1).max(99),
  image: z.string().max(1000),
});

const orderInputSchema = z.object({
  email: z.string().trim().email().max(255),
  phone: z.string().trim().min(8).max(20).regex(/^[\d\s+\-()]+$/),
  customerName: z.string().trim().min(1).max(255),
  address: z.string().trim().min(1).max(1000),
  province: z.string().trim().min(1).max(100),
  city: z.string().trim().min(1).max(100),
  district: z.string().trim().max(100).optional().default(""),
  postalCode: z.string().trim().min(3).max(10).regex(/^[\d\-]+$/),
  streetAddress: z.string().trim().max(500).optional().default(""),
  addressDetail: z.string().trim().max(500).optional().default(""),
  specialInstructions: z.string().max(1000).optional().default(""),
  shippingRateId: z.string().uuid().optional(),
  shippingMethodName: z.string().max(100).optional().default(""),
  shippingCost: z.number().int().min(0).optional().default(0),
  items: z.array(cartItemSchema).min(1).max(50),
});

function generateOrderNumber(): string {
  const ts = Date.now().toString(36).toUpperCase();
  const rand = Math.random().toString(36).substring(2, 6).toUpperCase();
  return `RX-${ts}${rand}`;
}

export const createOrder = createServerFn({ method: "POST" })
  .inputValidator((input: unknown) => orderInputSchema.parse(input))
  .handler(async ({ data }) => {
    const client = getAnonClient();
    const orderNumber = generateOrderNumber();
    const subtotal = data.items.reduce(
      (sum, item) => sum + item.price * item.quantity,
      0
    );
    const shippingCost = data.shippingCost ?? 0;
    const total = subtotal + shippingCost;

    const itemsJsonb = data.items.map((item) => ({
      product_id: item.productId,
      variant_id: item.variantId,
      product_name: item.name,
      size: item.size,
      price: item.price,
      quantity: item.quantity,
    }));

    const { data: result, error } = await client.rpc("create_guest_order", {
      p_order_number: orderNumber,
      p_email: data.email,
      p_phone: data.phone,
      p_customer_name: data.customerName,
      p_address: data.address,
      p_city: data.city,
      p_province: data.province,
      p_district: data.district || "",
      p_postal_code: data.postalCode,
      p_street_address: data.streetAddress || "",
      p_address_detail: data.addressDetail || "",
      p_special_instructions: data.specialInstructions || "",
      p_shipping_method_name: data.shippingMethodName || "",
      p_subtotal: subtotal,
      p_shipping_cost: shippingCost,
      p_total: total,
      p_items: itemsJsonb,
    } as any);

    if (error) {
      console.error("Order creation error:", error);
      throw new Error("Gagal membuat pesanan. Silakan coba lagi.");
    }

    const orderResult = result as any;

    // --- Request Midtrans Snap Token ---
    let snapToken = null;
    let redirectUrl = null;
    const midtransServerKey = process.env.MIDTRANS_SERVER_KEY;
    
    try {
      const authHeader = `Basic ${Buffer.from(midtransServerKey + ':').toString('base64')}`;
      const midtransResponse = await fetch('https://app.sandbox.midtrans.com/snap/v1/transactions', {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': authHeader
        },
        body: JSON.stringify({
          transaction_details: {
            order_id: orderNumber,
            gross_amount: total
          },
          customer_details: {
            first_name: data.customerName,
            email: data.email,
            phone: data.phone
          },
          item_details: data.items.map(item => ({
            id: item.productId,
            price: item.price,
            quantity: item.quantity,
            name: item.name
          })).concat([{
            id: 'shipping',
            price: shippingCost,
            quantity: 1,
            name: `Ongkir - ${data.shippingMethodName || 'Reguler'}`
          }])
        })
      });
      
      const midtransData = await midtransResponse.json();
      if (midtransData && midtransData.token) {
        snapToken = midtransData.token;
        redirectUrl = midtransData.redirect_url;
      } else {
        console.error("Midtrans API error:", midtransData);
      }
    } catch (err) {
      console.error("Midtrans fetch error:", err);
    }

    return {
      orderNumber: orderResult.order_number || orderNumber,
      orderId: orderResult.id,
      total,
      snapToken,
      redirectUrl
    };
  });

const paymentProofSchema = z.object({
  orderNumber: z.string().min(1).max(50),
  proofUrl: z.string().url().max(2000),
});

export const submitPaymentProof = createServerFn({ method: "POST" })
  .inputValidator((input: unknown) => paymentProofSchema.parse(input))
  .handler(async ({ data }) => {
    const client = getAnonClient();

    const { data: success, error } = await client.rpc("submit_order_payment_proof", {
      p_order_number: data.orderNumber,
      p_proof_url: data.proofUrl,
    } as any);

    if (error || !success) {
      console.error("Payment proof error:", error);
      throw new Error("Gagal menyimpan bukti pembayaran. Silakan coba lagi.");
    }

    return { success: true };
  });

const orderNumberSchema = z.object({
  orderNumber: z.string().min(1).max(50),
});

export const getOrderByNumber = createServerFn({ method: "POST" })
  .inputValidator((input: unknown) => orderNumberSchema.parse(input))
  .handler(async ({ data }) => {
    const client = getAnonClient();

    const { data: result, error } = await client.rpc("lookup_order", {
      p_order_number: data.orderNumber,
    } as any);

    if (error || !result) {
      return null;
    }

    return result as any;
  });

// --- Komerce / RajaOngkir API Functions ---

const searchQuerySchema = z.object({
  query: z.string().min(3).max(100),
});

export const searchDestination = createServerFn({ method: "POST" })
  .inputValidator((input: unknown) => searchQuerySchema.parse(input))
  .handler(async ({ data }) => {
    const apiKey = process.env.KOMERCE_API_KEY;
    try {
      const response = await fetch(`https://rajaongkir.komerce.id/api/v1/destination/domestic-destination?search=${encodeURIComponent(data.query)}`, {
        headers: { "key": apiKey }
      });
      const result = await response.json();
      return result?.data || [];
    } catch (e) {
      console.error("Search destination error:", e);
      return [];
    }
  });

const rateQuerySchema = z.object({
  destinationId: z.number(),
  weight: z.number().positive(),
});

export const getShippingRates = createServerFn({ method: "POST" })
  .inputValidator((input: unknown) => rateQuerySchema.parse(input))
  .handler(async ({ data }) => {
    const apiKey = process.env.KOMERCE_API_KEY;
    try {
      const formData = new URLSearchParams();
      formData.append("origin", "17567"); // 17567 = Pejaten Barat (Jakarta Selatan)
      formData.append("destination", data.destinationId.toString());
      formData.append("weight", Math.max(1000, data.weight).toString());
      formData.append("courier", "jne");

      const response = await fetch(`https://rajaongkir.komerce.id/api/v1/calculate/domestic-cost`, {
        method: "POST",
        headers: { 
          "key": apiKey,
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: formData.toString()
      });
      const result = await response.json();
      const allRates = result?.data || [];
      
      // Filter out JTR (Cargo/Trucking) services because they confuse retail buyers
      // We only want standard services like REG, YES, OKE, CTC (City Courier)
      const standardRates = allRates.filter((r: any) => !r.service.startsWith('JTR'));
      
      // Sort by price ascending
      return standardRates.sort((a: any, b: any) => a.cost - b.cost);
    } catch (e) {
      console.error("Get rates error:", e);
      return [];
    }
  });
