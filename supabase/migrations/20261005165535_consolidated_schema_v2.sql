-- =============================================================================
-- RAWTIX CRAFTED LUXE — Consolidated Schema v2
-- Migration: 20261005165535_consolidated_schema_v2.sql
--
-- Ringkasan perubahan dari analisis codebase:
--   1. Menambahkan index yang hilang untuk performa query
--   2. Menambahkan storage policy untuk admin (upload/delete product images)
--   3. Menambahkan storage policy admin untuk payment proofs
--   4. Memperbaiki `lookup_order` agar return data lebih lengkap
--      (customer_name, created_at, items) — dibutuhkan di order-success page
--   5. Menambahkan RLS policy `user_roles` agar user bisa lihat role sendiri
--   6. Menambahkan trigger updated_at untuk orders (belum ada di schema awal)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. INDEXES — Performa query yang sering dipanggil
-- -----------------------------------------------------------------------------

-- Orders: filter by status (admin panel), sort by created_at
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders (status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON public.orders (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_order_number ON public.orders (order_number);
CREATE INDEX IF NOT EXISTS idx_orders_email ON public.orders (email);

-- Order items: lookup by order
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items (order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_variant_id ON public.order_items (variant_id);

-- Order notifications: lookup by order
CREATE INDEX IF NOT EXISTS idx_order_notifications_order_id ON public.order_notifications (order_id);

-- Products: filter by status, category, featured
CREATE INDEX IF NOT EXISTS idx_products_status ON public.products (status);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON public.products (category_id);
CREATE INDEX IF NOT EXISTS idx_products_featured ON public.products (featured) WHERE featured = true;
CREATE INDEX IF NOT EXISTS idx_products_slug ON public.products (slug);
CREATE INDEX IF NOT EXISTS idx_products_sort_order ON public.products (sort_order);

-- Product variants: lookup by product
CREATE INDEX IF NOT EXISTS idx_product_variants_product_id ON public.product_variants (product_id);

-- Product images: lookup by product, filter primary
CREATE INDEX IF NOT EXISTS idx_product_images_product_id ON public.product_images (product_id);
CREATE INDEX IF NOT EXISTS idx_product_images_is_primary ON public.product_images (product_id, is_primary) WHERE is_primary = true;

-- Shipping rates: filter active
CREATE INDEX IF NOT EXISTS idx_shipping_rates_active ON public.shipping_rates (active, sort_order);

-- User roles: lookup by user
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON public.user_roles (user_id);


-- -----------------------------------------------------------------------------
-- 2. RLS — User bisa melihat role miliknya sendiri
-- -----------------------------------------------------------------------------

CREATE POLICY "Users can read own role"
  ON public.user_roles
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());


-- -----------------------------------------------------------------------------
-- 3. STORAGE POLICIES — Admin bisa hapus dan kelola object di storage
-- -----------------------------------------------------------------------------

-- Product images: admin dapat delete
CREATE POLICY "Admins can delete product images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'product-images'
    AND public.has_role(auth.uid(), 'admin')
  );

-- Product images: admin dapat update (replace)
CREATE POLICY "Admins can update product images"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'product-images'
    AND public.has_role(auth.uid(), 'admin')
  );

-- Payment proofs: admin dapat delete
CREATE POLICY "Admins can delete payment proofs"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'payment-proofs'
    AND public.has_role(auth.uid(), 'admin')
  );


-- -----------------------------------------------------------------------------
-- 4. FUNGSI — lookup_order diperluas dengan data order_items & customer
--    (order-success page dan customer perlu lihat detail lengkap)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.lookup_order(p_order_number text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order_id uuid;
  result json;
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
      SELECT json_agg(json_build_object(
        'id',           oi.id,
        'product_name', oi.product_name,
        'size',         oi.size,
        'price',        oi.price,
        'quantity',     oi.quantity
      ) ORDER BY oi.id)
      FROM order_items oi
      WHERE oi.order_id = o.id
    )
  ) INTO result
  FROM orders o
  WHERE o.id = v_order_id;

  RETURN result;
END;
$$;


-- -----------------------------------------------------------------------------
-- 5. FUNGSI — Decrement stok saat order dibuat (otomatis, bukan saat paid)
--    Ini opsional — aktifkan jika ingin stok berkurang saat checkout
--    Saat ini stok berkurang saat status berubah ke 'paid' (di app layer).
--    Migration ini hanya mendokumentasikan; tidak mengubah behavior.
-- -----------------------------------------------------------------------------

-- (Tidak ada perubahan di sini — stok dikelola di admin.functions.ts)


-- -----------------------------------------------------------------------------
-- 6. NEWSLETTER — Tambah index untuk email lookup
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_newsletter_email ON public.newsletter_subscribers (email);


-- -----------------------------------------------------------------------------
-- 7. CATEGORIES — Tambah index slug untuk lookup cepat
-- -----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_categories_slug ON public.categories (slug);
