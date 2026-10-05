-- =============================================================================
-- RAWTIX CRAFTED LUXE — Seed Data
-- File: supabase/seed.sql
--
-- Berisi data awal untuk:
--   - categories (4 kategori)
--   - products (6 produk)
--   - product_variants (ukuran S, M, L, XL per produk)
--   - shipping_rates (3 opsi pengiriman)
--
-- Semua INSERT menggunakan ON CONFLICT DO NOTHING — aman dijalankan
-- berulang kali tanpa error duplicate key.
--
-- URL Storage: https://kfzjviclsplcmwdvyvuq.supabase.co/storage/v1/object/public/product-images/<filename>
-- =============================================================================


-- =============================================================================
-- CATEGORIES
-- =============================================================================

INSERT INTO public.categories (id, name, slug, sort_order) VALUES
  ('11111111-0000-0000-0000-000000000001', 'T-Shirts',  'tshirts',  1),
  ('11111111-0000-0000-0000-000000000002', 'Hoodies',   'hoodies',  2),
  ('11111111-0000-0000-0000-000000000003', 'Bottoms',   'bottoms',  3),
  ('11111111-0000-0000-0000-000000000004', 'Headwear',  'headwear', 4)
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- PRODUCTS
-- =============================================================================

INSERT INTO public.products (id, name, slug, description, price, category_id, status, featured, sort_order) VALUES
  (
    '22222222-0000-0000-0000-000000000001',
    'Midnight Tee',
    'midnight-tee',
    'Essential heavyweight tee dalam colorway hitam pekat. Ditenun dengan cotton 240gsm untuk durabilitas dan drape yang premium. Fit boxy dengan shoulder drop untuk silhouette yang lebih modern.',
    299000,
    '11111111-0000-0000-0000-000000000001',
    'active',
    true,
    1
  ),
  (
    '22222222-0000-0000-0000-000000000002',
    'Phantom LS',
    'phantom-ls',
    'Long sleeve dengan detail jahitan tonal. Fabric ripstop ringan yang breathable namun tetap memberikan structure. Cocok untuk layering.',
    349000,
    '11111111-0000-0000-0000-000000000001',
    'active',
    true,
    2
  ),
  (
    '22222222-0000-0000-0000-000000000003',
    'Raw Hoodie',
    'raw-hoodie',
    'Heavyweight pullover hoodie dengan raw hem finish di semua tepi. French terry 380gsm. Kangaroo pocket berukuran besar dengan hidden zip.',
    549000,
    '11111111-0000-0000-0000-000000000002',
    'active',
    true,
    3
  ),
  (
    '22222222-0000-0000-0000-000000000004',
    'Shadow Cargo',
    'shadow-cargo',
    'Cargo pants dengan 6 pocket fungsional. Fabric ripstop 180gsm yang ringan namun tahan lama. Adjustable hem dan drawstring waist.',
    599000,
    '11111111-0000-0000-0000-000000000003',
    'active',
    true,
    4
  ),
  (
    '22222222-0000-0000-0000-000000000005',
    'Urban Wide',
    'urban-wide',
    'Wide-leg trousers dengan silhouette yang clean dan modern. Fabric wool-blend yang memberikan drape natural. Side seam pocket tersembunyi.',
    499000,
    '11111111-0000-0000-0000-000000000003',
    'active',
    false,
    5
  ),
  (
    '22222222-0000-0000-0000-000000000006',
    'Stealth Cap',
    'stealth-cap',
    'Six-panel structured cap dengan brim flat. Logo tonal embroidery di depan. Adjustable snapback closure.',
    199000,
    '11111111-0000-0000-0000-000000000004',
    'active',
    true,
    6
  )
ON CONFLICT (id) DO NOTHING;


-- =============================================================================
-- PRODUCT VARIANTS
-- =============================================================================

INSERT INTO public.product_variants (product_id, size, stock) VALUES
  -- Midnight Tee
  ('22222222-0000-0000-0000-000000000001', 'S',  15),
  ('22222222-0000-0000-0000-000000000001', 'M',  20),
  ('22222222-0000-0000-0000-000000000001', 'L',  20),
  ('22222222-0000-0000-0000-000000000001', 'XL', 10),
  -- Phantom LS
  ('22222222-0000-0000-0000-000000000002', 'S',  10),
  ('22222222-0000-0000-0000-000000000002', 'M',  15),
  ('22222222-0000-0000-0000-000000000002', 'L',  15),
  ('22222222-0000-0000-0000-000000000002', 'XL', 8),
  -- Raw Hoodie
  ('22222222-0000-0000-0000-000000000003', 'S',  8),
  ('22222222-0000-0000-0000-000000000003', 'M',  12),
  ('22222222-0000-0000-0000-000000000003', 'L',  12),
  ('22222222-0000-0000-0000-000000000003', 'XL', 5),
  -- Shadow Cargo
  ('22222222-0000-0000-0000-000000000004', 'S',  8),
  ('22222222-0000-0000-0000-000000000004', 'M',  10),
  ('22222222-0000-0000-0000-000000000004', 'L',  10),
  ('22222222-0000-0000-0000-000000000004', 'XL', 5),
  -- Urban Wide
  ('22222222-0000-0000-0000-000000000005', 'S',  5),
  ('22222222-0000-0000-0000-000000000005', 'M',  8),
  ('22222222-0000-0000-0000-000000000005', 'L',  8),
  ('22222222-0000-0000-0000-000000000005', 'XL', 4),
  -- Stealth Cap
  ('22222222-0000-0000-0000-000000000006', 'One Size', 25)
ON CONFLICT DO NOTHING;


-- =============================================================================
-- PRODUCT IMAGES
-- =============================================================================

INSERT INTO public.product_images (product_id, url, alt_text, is_primary, sort_order) VALUES
  ('22222222-0000-0000-0000-000000000001', 'https://kfzjviclsplcmwdvyvuq.supabase.co/storage/v1/object/public/product-images/midnight-tee.jpg',  'Midnight Tee',  true, 0),
  ('22222222-0000-0000-0000-000000000002', 'https://kfzjviclsplcmwdvyvuq.supabase.co/storage/v1/object/public/product-images/phantom-ls.jpg',    'Phantom LS',    true, 0),
  ('22222222-0000-0000-0000-000000000003', 'https://kfzjviclsplcmwdvyvuq.supabase.co/storage/v1/object/public/product-images/raw-hoodie.jpg',    'Raw Hoodie',    true, 0),
  ('22222222-0000-0000-0000-000000000004', 'https://kfzjviclsplcmwdvyvuq.supabase.co/storage/v1/object/public/product-images/shadow-cargo.jpg',  'Shadow Cargo',  true, 0),
  ('22222222-0000-0000-0000-000000000005', 'https://kfzjviclsplcmwdvyvuq.supabase.co/storage/v1/object/public/product-images/urban-wide.jpg',    'Urban Wide',    true, 0),
  ('22222222-0000-0000-0000-000000000006', 'https://kfzjviclsplcmwdvyvuq.supabase.co/storage/v1/object/public/product-images/stealth-cap.jpg',   'Stealth Cap',   true, 0)
ON CONFLICT DO NOTHING;


-- =============================================================================
-- SHIPPING RATES
-- =============================================================================

INSERT INTO public.shipping_rates (name, price, is_default, active, sort_order) VALUES
  ('JNE REG',     18000, true,  true, 1),
  ('JNE YES',     28000, false, true, 2),
  ('SiCepat REG', 15000, false, true, 3)
ON CONFLICT DO NOTHING;
