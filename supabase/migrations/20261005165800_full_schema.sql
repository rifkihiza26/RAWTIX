-- =============================================================================
-- RAWTIX CRAFTED LUXE — Full Schema (Fresh Install)
-- Migration: 20261005165800_full_schema.sql
--
-- File ini adalah konsolidasi LENGKAP dari semua migration sebelumnya:
--   1. 20260404193149 — Schema dasar (enums, tabel, storage)
--   2. 20260404193211 — Perbaikan RLS orders & newsletter
--   3. 20260404211829 — Payment proof columns + storage bucket
--   4. 20260406135958 — RBAC: app_role, user_roles, has_role()
--   5. 20260406140550 — Storage policy: public upload product images
--   6. 20260406144941 — Kolom alamat terstruktur, shipping_rates, order_notifications
--   7. 20260406160135 — Admin RLS policies
--   8. 20260406160501 — SECURITY DEFINER functions
--   9. 20261005165535 — Indexes, storage admin policies, lookup_order v2
--
-- Gunakan file ini untuk fresh deployment / Supabase project baru.
-- =============================================================================


-- =============================================================================
-- BAGIAN 1: ENUMS
-- =============================================================================

CREATE TYPE public.product_status AS ENUM ('active', 'sold_out', 'preorder', 'draft');

CREATE TYPE public.order_status AS ENUM (
  'pending',
  'paid',
  'processing',
  'shipped',
  'delivered',
  'cancelled'
);

CREATE TYPE public.app_role AS ENUM ('admin');


-- =============================================================================
-- BAGIAN 2: FUNGSI HELPER
-- (dibuat SEBELUM tabel & RLS agar bisa langsung dipakai)
-- =============================================================================

-- Trigger: auto-update kolom updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;


-- =============================================================================
-- BAGIAN 3: TABEL user_roles + fungsi has_role()
-- (harus ada SEBELUM RLS policy tabel lain yang memanggil has_role)
-- =============================================================================

CREATE TABLE public.user_roles (
  id      UUID     NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID     NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role    app_role NOT NULL,
  UNIQUE (user_id, role)
);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- has_role() dibuat di sini agar tersedia saat CREATE POLICY di bawah
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role app_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role = _role
  )
$$;

-- RLS: admin bisa baca semua role, user hanya bisa baca role sendiri
CREATE POLICY "Admins can read roles"
  ON public.user_roles FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Users can read own role"
  ON public.user_roles FOR SELECT TO authenticated
  USING (user_id = auth.uid());


-- =============================================================================
-- BAGIAN 4: TABEL-TABEL UTAMA
-- =============================================================================

-- ------------------------------------
-- categories
-- ------------------------------------
CREATE TABLE public.categories (
  id         UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name       TEXT        NOT NULL,
  slug       TEXT        NOT NULL UNIQUE,
  sort_order INTEGER     NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Categories are publicly readable"
  ON public.categories FOR SELECT USING (true);

CREATE POLICY "Admins can insert categories"
  ON public.categories FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update categories"
  ON public.categories FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete categories"
  ON public.categories FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));


-- ------------------------------------
-- products
-- ------------------------------------
CREATE TABLE public.products (
  id                      UUID           NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name                    TEXT           NOT NULL,
  slug                    TEXT           NOT NULL UNIQUE,
  description             TEXT,
  price                   INTEGER        NOT NULL DEFAULT 0,
  category_id             UUID           REFERENCES public.categories(id) ON DELETE SET NULL,
  status                  product_status NOT NULL DEFAULT 'draft',
  preorder_estimated_date DATE,
  featured                BOOLEAN        NOT NULL DEFAULT false,
  sort_order              INTEGER        NOT NULL DEFAULT 0,
  created_at              TIMESTAMPTZ    NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ    NOT NULL DEFAULT now()
);

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Public bisa lihat produk selain draft; admin bisa lihat semua termasuk draft
CREATE POLICY "Active products are publicly readable"
  ON public.products FOR SELECT
  USING (status != 'draft');

CREATE POLICY "Admins can view all products"
  ON public.products FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can insert products"
  ON public.products FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update products"
  ON public.products FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete products"
  ON public.products FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));


-- ------------------------------------
-- product_images
-- ------------------------------------
CREATE TABLE public.product_images (
  id         UUID    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id UUID    NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  url        TEXT    NOT NULL,
  alt_text   TEXT,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  sort_order INTEGER NOT NULL DEFAULT 0
);

ALTER TABLE public.product_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Product images are publicly readable"
  ON public.product_images FOR SELECT USING (true);

CREATE POLICY "Admins can insert images"
  ON public.product_images FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update images"
  ON public.product_images FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete images"
  ON public.product_images FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));


-- ------------------------------------
-- product_variants
-- ------------------------------------
CREATE TABLE public.product_variants (
  id         UUID    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id UUID    NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  size       TEXT    NOT NULL,
  stock      INTEGER NOT NULL DEFAULT 0,
  sku        TEXT
);

ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Product variants are publicly readable"
  ON public.product_variants FOR SELECT USING (true);

CREATE POLICY "Admins can insert variants"
  ON public.product_variants FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update variants"
  ON public.product_variants FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete variants"
  ON public.product_variants FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));


-- ------------------------------------
-- orders
-- ------------------------------------
CREATE TABLE public.orders (
  id                         UUID         NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  order_number               TEXT         NOT NULL UNIQUE,
  email                      TEXT         NOT NULL,
  phone                      TEXT,
  customer_name              TEXT         NOT NULL,
  -- Alamat gabungan (digunakan sebagai fallback / display)
  address                    TEXT         NOT NULL,
  -- Alamat terstruktur
  province                   TEXT         NOT NULL,
  city                       TEXT         NOT NULL,
  district                   TEXT,
  postal_code                TEXT         NOT NULL,
  street_address             TEXT,
  address_detail             TEXT,
  -- Order info
  special_instructions       TEXT,
  subtotal                   INTEGER      NOT NULL DEFAULT 0,
  shipping_cost              INTEGER      NOT NULL DEFAULT 0,
  total                      INTEGER      NOT NULL DEFAULT 0,
  status                     order_status NOT NULL DEFAULT 'pending',
  -- Payment
  payment_method             TEXT,
  payment_reference          TEXT,
  payment_proof_url          TEXT,
  payment_proof_submitted_at TIMESTAMPTZ,
  -- Shipping
  shipping_method_name       TEXT,
  shipping_tracking          TEXT,
  -- Timestamps
  created_at                 TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at                 TIMESTAMPTZ  NOT NULL DEFAULT now()
);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Publik tidak bisa SELECT langsung; gunakan lookup_order() untuk guest
CREATE POLICY "Orders are not publicly accessible"
  ON public.orders FOR SELECT USING (false);

-- Siapa saja (termasuk anon) bisa INSERT via create_guest_order()
CREATE POLICY "Anyone can create orders"
  ON public.orders FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can view all orders"
  ON public.orders FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update orders"
  ON public.orders FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));


-- ------------------------------------
-- order_items
-- ------------------------------------
CREATE TABLE public.order_items (
  id           UUID    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id     UUID    NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id   UUID    REFERENCES public.products(id) ON DELETE SET NULL,
  variant_id   UUID    REFERENCES public.product_variants(id) ON DELETE SET NULL,
  product_name TEXT    NOT NULL,
  size         TEXT    NOT NULL,
  price        INTEGER NOT NULL,
  quantity     INTEGER NOT NULL DEFAULT 1
);

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Order items are not publicly accessible"
  ON public.order_items FOR SELECT USING (false);

CREATE POLICY "Anyone can create order items"
  ON public.order_items FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can view all order items"
  ON public.order_items FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));


-- ------------------------------------
-- order_notifications
-- ------------------------------------
CREATE TABLE public.order_notifications (
  id         UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id   UUID        NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  event_type TEXT        NOT NULL,
  channel    TEXT        NOT NULL DEFAULT 'email',
  status     TEXT        NOT NULL DEFAULT 'pending',
  metadata   JSONB       NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.order_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Notifications not publicly accessible"
  ON public.order_notifications FOR SELECT USING (false);

CREATE POLICY "Anyone can create notifications"
  ON public.order_notifications FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can view all notifications"
  ON public.order_notifications FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));


-- ------------------------------------
-- shipping_rates
-- ------------------------------------
CREATE TABLE public.shipping_rates (
  id         UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name       TEXT        NOT NULL,
  price      INTEGER     NOT NULL DEFAULT 0,
  is_default BOOLEAN     NOT NULL DEFAULT false,
  active     BOOLEAN     NOT NULL DEFAULT true,
  sort_order INTEGER     NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.shipping_rates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Shipping rates are publicly readable"
  ON public.shipping_rates FOR SELECT USING (true);

CREATE POLICY "Admins can insert shipping rates"
  ON public.shipping_rates FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can update shipping rates"
  ON public.shipping_rates FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can delete shipping rates"
  ON public.shipping_rates FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'admin'));


-- ------------------------------------
-- newsletter_subscribers
-- ------------------------------------
CREATE TABLE public.newsletter_subscribers (
  id            UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  email         TEXT        NOT NULL UNIQUE,
  subscribed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.newsletter_subscribers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can subscribe"
  ON public.newsletter_subscribers FOR INSERT
  WITH CHECK (email IS NOT NULL AND length(email) > 0 AND length(email) < 256);


-- =============================================================================
-- BAGIAN 5: INDEXES
-- =============================================================================

-- categories
CREATE INDEX idx_categories_slug       ON public.categories (slug);
CREATE INDEX idx_categories_sort_order ON public.categories (sort_order);

-- products
CREATE INDEX idx_products_status      ON public.products (status);
CREATE INDEX idx_products_slug        ON public.products (slug);
CREATE INDEX idx_products_category_id ON public.products (category_id);
CREATE INDEX idx_products_sort_order  ON public.products (sort_order);
CREATE INDEX idx_products_featured    ON public.products (featured) WHERE featured = true;

-- product_images
CREATE INDEX idx_product_images_product_id ON public.product_images (product_id);
CREATE INDEX idx_product_images_primary    ON public.product_images (product_id, is_primary) WHERE is_primary = true;

-- product_variants
CREATE INDEX idx_product_variants_product_id ON public.product_variants (product_id);

-- orders
CREATE INDEX idx_orders_status       ON public.orders (status);
CREATE INDEX idx_orders_created_at   ON public.orders (created_at DESC);
CREATE INDEX idx_orders_order_number ON public.orders (order_number);
CREATE INDEX idx_orders_email        ON public.orders (email);

-- order_items
CREATE INDEX idx_order_items_order_id   ON public.order_items (order_id);
CREATE INDEX idx_order_items_variant_id ON public.order_items (variant_id);

-- order_notifications
CREATE INDEX idx_order_notifications_order_id ON public.order_notifications (order_id);

-- shipping_rates
CREATE INDEX idx_shipping_rates_active ON public.shipping_rates (active, sort_order);

-- user_roles
CREATE INDEX idx_user_roles_user_id ON public.user_roles (user_id);

-- newsletter
CREATE INDEX idx_newsletter_email ON public.newsletter_subscribers (email);


-- =============================================================================
-- BAGIAN 6: FUNGSI SECURITY DEFINER
-- =============================================================================

-- ------------------------------------
-- create_guest_order — dipanggil dari server function checkout (anon)
-- ------------------------------------
CREATE OR REPLACE FUNCTION public.create_guest_order(
  p_order_number         text,
  p_email                text,
  p_phone                text,
  p_customer_name        text,
  p_address              text,
  p_city                 text,
  p_province             text,
  p_district             text,
  p_postal_code          text,
  p_street_address       text,
  p_address_detail       text,
  p_special_instructions text,
  p_shipping_method_name text,
  p_subtotal             int,
  p_shipping_cost        int,
  p_total                int,
  p_items                jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order_id uuid;
  v_item     jsonb;
BEGIN
  INSERT INTO orders (
    order_number, email, phone, customer_name,
    address, city, province, district, postal_code,
    street_address, address_detail, special_instructions,
    shipping_method_name, subtotal, shipping_cost, total, status
  ) VALUES (
    p_order_number, p_email, p_phone, p_customer_name,
    p_address, p_city, p_province,
    NULLIF(p_district, ''), p_postal_code,
    NULLIF(p_street_address, ''), NULLIF(p_address_detail, ''),
    NULLIF(p_special_instructions, ''), NULLIF(p_shipping_method_name, ''),
    p_subtotal, p_shipping_cost, p_total, 'pending'
  ) RETURNING id INTO v_order_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO order_items (
      order_id, product_id, variant_id,
      product_name, size, price, quantity
    ) VALUES (
      v_order_id,
      (v_item->>'product_id')::uuid,
      (v_item->>'variant_id')::uuid,
      v_item->>'product_name',
      v_item->>'size',
      (v_item->>'price')::int,
      (v_item->>'quantity')::int
    );
  END LOOP;

  INSERT INTO order_notifications (order_id, event_type, channel, status)
  VALUES (v_order_id, 'order_created', 'email', 'pending');

  RETURN json_build_object('id', v_order_id, 'order_number', p_order_number);
END;
$$;


-- ------------------------------------
-- lookup_order — bisa dipanggil anon, return detail lengkap termasuk items
-- ------------------------------------
CREATE OR REPLACE FUNCTION public.lookup_order(p_order_number text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order_id uuid;
  result     json;
BEGIN
  SELECT id INTO v_order_id
  FROM orders
  WHERE order_number = p_order_number;

  IF v_order_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT json_build_object(
    'id',                         o.id,
    'order_number',               o.order_number,
    'customer_name',              o.customer_name,
    'email',                      o.email,
    'total',                      o.total,
    'subtotal',                   o.subtotal,
    'shipping_cost',              o.shipping_cost,
    'shipping_method_name',       o.shipping_method_name,
    'status',                     o.status,
    'payment_method',             o.payment_method,
    'payment_proof_url',          o.payment_proof_url,
    'payment_proof_submitted_at', o.payment_proof_submitted_at,
    'created_at',                 o.created_at,
    'items', (
      SELECT json_agg(
        json_build_object(
          'id',           oi.id,
          'product_name', oi.product_name,
          'size',         oi.size,
          'price',        oi.price,
          'quantity',     oi.quantity
        ) ORDER BY oi.id
      )
      FROM order_items oi
      WHERE oi.order_id = o.id
    )
  ) INTO result
  FROM orders o
  WHERE o.id = v_order_id;

  RETURN result;
END;
$$;


-- ------------------------------------
-- submit_order_payment_proof — upload bukti bayar (anon)
-- ------------------------------------
CREATE OR REPLACE FUNCTION public.submit_order_payment_proof(
  p_order_number text,
  p_proof_url    text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order_id uuid;
BEGIN
  SELECT id INTO v_order_id
  FROM orders
  WHERE order_number = p_order_number;

  IF v_order_id IS NULL THEN
    RETURN false;
  END IF;

  UPDATE orders
  SET payment_proof_url          = p_proof_url,
      payment_proof_submitted_at = now(),
      payment_method             = 'transfer_bca'
  WHERE id = v_order_id;

  INSERT INTO order_notifications (order_id, event_type, channel, status)
  VALUES (v_order_id, 'payment_proof_submitted', 'email', 'pending');

  RETURN true;
END;
$$;


-- =============================================================================
-- BAGIAN 7: STORAGE BUCKETS & POLICIES
-- =============================================================================

-- ------------------------------------
-- Bucket: product-images (public read)
-- ------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true);

CREATE POLICY "Product images are publicly accessible"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'product-images');

CREATE POLICY "Anyone can upload product images"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'product-images');

CREATE POLICY "Admins can update product images"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'product-images'
    AND public.has_role(auth.uid(), 'admin')
  );

CREATE POLICY "Admins can delete product images"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'product-images'
    AND public.has_role(auth.uid(), 'admin')
  );


-- ------------------------------------
-- Bucket: payment-proofs (public — admin verifikasi via URL)
-- ------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('payment-proofs', 'payment-proofs', true);

CREATE POLICY "Anyone can upload payment proofs"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'payment-proofs');

CREATE POLICY "Payment proofs are publicly readable"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'payment-proofs');

CREATE POLICY "Admins can delete payment proofs"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'payment-proofs'
    AND public.has_role(auth.uid(), 'admin')
  );
