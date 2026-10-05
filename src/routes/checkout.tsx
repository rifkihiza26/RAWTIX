import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useState, useEffect, useRef } from "react";
import { Header } from "@/components/layout/Header";
import { Footer } from "@/components/layout/Footer";
import { useCart } from "@/hooks/useCart";
import { formatPrice } from "@/components/product/ProductCard";
import { createOrder, searchDestination, getShippingRates } from "@/utils/orders.functions";
import { useServerFn } from "@tanstack/react-start";
import { toast } from "sonner";

declare global {
  interface Window {
    snap: any;
  }
}

export const Route = createFileRoute("/checkout")({
  component: CheckoutPage,
});

interface ShippingRate {
  service: string;
  description: string;
  cost: number;
  etd: string;
}

interface DestinationOption {
  id: number;
  label: string;
  province_name: string;
  city_name: string;
  district_name: string;
  subdistrict_name: string;
  zip_code: string;
}

interface FormErrors {
  email?: string;
  phone?: string;
  customerName?: string;
  streetAddress?: string;
  destination?: string;
  shipping?: string;
}

function validateForm(form: any): FormErrors {
  const errors: FormErrors = {};

  if (!form.email.trim()) errors.email = "Email wajib diisi";
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email))
    errors.email = "Format email tidak valid";

  if (!form.phone.trim()) errors.phone = "Nomor telepon wajib diisi";
  else if (!/^[\d\s+\-()]{8,20}$/.test(form.phone))
    errors.phone = "Format nomor tidak valid";

  if (!form.customerName.trim()) errors.customerName = "Nama wajib diisi";
  if (!form.streetAddress.trim()) errors.streetAddress = "Alamat jalan wajib diisi";
  
  if (!form.destinationId) errors.destination = "Pilih kecamatan/kota dari saran pencarian";
  if (!form.selectedShipping) errors.shipping = "Pilih metode pengiriman";

  return errors;
}

function CheckoutPage() {
  const { items, subtotal, clearCart } = useCart();
  const navigate = useNavigate();
  const createOrderFn = useServerFn(createOrder);
  const searchDestinationFn = useServerFn(searchDestination);
  const getShippingRatesFn = useServerFn(getShippingRates);

  const [shippingRates, setShippingRates] = useState<ShippingRate[]>([]);
  const [form, setForm] = useState({
    email: "",
    phone: "",
    customerName: "",
    province: "",
    city: "",
    district: "",
    postalCode: "",
    streetAddress: "",
    addressDetail: "",
    specialInstructions: "",
    destinationId: 0,
    selectedShipping: "",
  });
  const [errors, setErrors] = useState<FormErrors>({});
  const [loading, setLoading] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  // Search Destination State
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<DestinationOption[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [showDropdown, setShowDropdown] = useState(false);
  const searchRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (searchRef.current && !searchRef.current.contains(event.target as Node)) {
        setShowDropdown(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  useEffect(() => {
    if (searchQuery.length < 3) {
      setSearchResults([]);
      return;
    }
    const timer = setTimeout(async () => {
      setIsSearching(true);
      try {
        const results = await searchDestinationFn({ data: { query: searchQuery } });
        setSearchResults(results);
        setShowDropdown(true);
      } catch (err) {
        console.error(err);
      } finally {
        setIsSearching(false);
      }
    }, 500);

    return () => clearTimeout(timer);
  }, [searchQuery, searchDestinationFn]);

  const selectDestination = async (opt: DestinationOption) => {
    setSearchQuery(opt.label);
    setShowDropdown(false);
    setForm(prev => ({
      ...prev,
      destinationId: opt.id,
      province: opt.province_name,
      city: opt.city_name,
      district: opt.district_name || opt.subdistrict_name,
      postalCode: opt.zip_code,
      selectedShipping: "" // reset shipping
    }));

    if (submitted) {
      setErrors(prev => ({ ...prev, destination: undefined }));
    }

    // Fetch Rates
    try {
      const weight = items.reduce((sum, item) => sum + (item.quantity * 250), 0); // asumsi 1 item = 250gr
      const rates = await getShippingRatesFn({ 
        data: { destinationId: opt.id, weight: Math.max(1000, weight) } 
      });
      setShippingRates(rates);
      if (rates.length > 0) {
        setForm(prev => ({ ...prev, selectedShipping: rates[0].service }));
      }
    } catch (err) {
      console.error(err);
      toast.error("Gagal mengambil tarif pengiriman.");
    }
  };

  const selectedRate = shippingRates.find((r) => r.service === form.selectedShipping);
  const shippingCost = selectedRate?.cost ?? 0;
  const total = subtotal + shippingCost;

  const updateField = (field: string, value: string) => {
    setForm((prev) => ({ ...prev, [field]: value }));
    if (submitted) {
      setErrors((prev) => ({ ...prev, [field]: undefined }));
    }
  };

  const inputClass = (field: keyof FormErrors) =>
    `w-full bg-transparent border ${
      errors[field] ? "border-destructive/60" : "border-border"
    } px-4 py-3 text-sm outline-none focus:border-foreground transition-colors placeholder:text-muted-foreground`;

  if (items.length === 0) {
    return (
      <div className="min-h-screen bg-background text-foreground">
        <Header />
        <div className="pt-[72px] flex items-center justify-center py-32">
          <div className="text-center">
            <p className="text-muted-foreground text-sm">Keranjang kosong.</p>
            <Link
              to="/shop"
              className="mt-4 inline-block text-xs tracking-[0.2em] uppercase border-b border-foreground pb-1"
            >
              Belanja dulu
            </Link>
          </div>
        </div>
      </div>
    );
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitted(true);

    const validationErrors = validateForm(form);
    setErrors(validationErrors);

    if (Object.keys(validationErrors).length > 0) {
      toast.error("Mohon lengkapi semua field yang diperlukan");
      return;
    }

    setLoading(true);

    try {
      const concatenatedAddress = [
        form.streetAddress,
        form.addressDetail,
        form.district,
        form.city,
        form.province,
        form.postalCode,
      ]
        .filter(Boolean)
        .join(", ");

      const result = await createOrderFn({
        data: {
          email: form.email.trim(),
          phone: form.phone.trim(),
          customerName: form.customerName.trim(),
          address: concatenatedAddress,
          province: form.province.trim(),
          city: form.city.trim(),
          district: form.district.trim(),
          postalCode: form.postalCode.trim(),
          streetAddress: form.streetAddress.trim(),
          addressDetail: form.addressDetail.trim(),
          specialInstructions: form.specialInstructions.trim(),
          shippingRateId: undefined,
          shippingMethodName: `JNE ${selectedRate?.service || ""}`,
          shippingCost,
          items: items.map((item) => ({
            productId: item.productId,
            variantId: item.variantId,
            name: item.name,
            size: item.size,
            price: item.price,
            quantity: item.quantity,
            image: item.image,
          })),
        },
      });

      clearCart();

      // Trigger Midtrans Snap
      if (result.snapToken && window.snap) {
        window.snap.pay(result.snapToken, {
          onSuccess: function () {
            navigate({ to: "/order-success", search: { order: result.orderNumber } });
          },
          onPending: function () {
            navigate({ to: "/order-success", search: { order: result.orderNumber } });
          },
          onError: function () {
            toast.error("Pembayaran gagal. Silakan coba lagi nanti.");
            navigate({ to: "/order-success", search: { order: result.orderNumber } });
          },
          onClose: function () {
            toast.info("Anda menutup popup pembayaran.");
            navigate({ to: "/order-success", search: { order: result.orderNumber } });
          }
        });
      } else {
        if (result.redirectUrl) {
          window.location.href = result.redirectUrl;
        } else {
          navigate({ to: "/order-success", search: { order: result.orderNumber } });
        }
      }
    } catch (err) {
      console.error("Order error:", err);
      toast.error(err instanceof Error ? err.message : "Gagal membuat pesanan. Silakan coba lagi.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-background text-foreground">
      <Header />

      <main className="pt-[72px] px-4 sm:px-6 md:px-10 py-10">
        <div className="max-w-5xl mx-auto grid grid-cols-1 lg:grid-cols-[1fr_380px] gap-8 lg:gap-10">
          {/* Form */}
          <form onSubmit={handleSubmit} className="space-y-8">
            <h1 className="font-heading text-xs tracking-[0.3em] uppercase">Checkout</h1>

            {/* Contact */}
            <div>
              <h2 className="text-xs tracking-[0.2em] uppercase mb-4">Kontak</h2>
              <div className="space-y-3">
                <div>
                  <input
                    type="email"
                    placeholder="Email"
                    value={form.email}
                    onChange={(e) => updateField("email", e.target.value)}
                    className={inputClass("email")}
                  />
                  {errors.email && <p className="text-destructive text-xs mt-1">{errors.email}</p>}
                </div>
                <div>
                  <input
                    type="tel"
                    placeholder="Nomor telepon"
                    value={form.phone}
                    onChange={(e) => updateField("phone", e.target.value)}
                    className={inputClass("phone")}
                  />
                  {errors.phone && <p className="text-destructive text-xs mt-1">{errors.phone}</p>}
                </div>
              </div>
            </div>

            {/* Address */}
            <div>
              <h2 className="text-xs tracking-[0.2em] uppercase mb-4">Alamat Pengiriman</h2>
              <div className="space-y-3">
                <div>
                  <input
                    type="text"
                    placeholder="Nama lengkap penerima"
                    value={form.customerName}
                    onChange={(e) => updateField("customerName", e.target.value)}
                    className={inputClass("customerName")}
                  />
                  {errors.customerName && <p className="text-destructive text-xs mt-1">{errors.customerName}</p>}
                </div>
                
                <div className="relative" ref={searchRef}>
                  <input
                    type="text"
                    placeholder="Cari Kecamatan / Kota..."
                    value={searchQuery}
                    onChange={(e) => {
                      setSearchQuery(e.target.value);
                      if (form.destinationId) {
                        setForm(prev => ({ ...prev, destinationId: 0, province: "", city: "", district: "", postalCode: "" }));
                        setShippingRates([]);
                      }
                    }}
                    onFocus={() => {
                      if (searchResults.length > 0) setShowDropdown(true);
                    }}
                    className={`w-full bg-transparent border ${errors.destination ? "border-destructive/60" : "border-border"} px-4 py-3 text-sm outline-none focus:border-foreground transition-colors placeholder:text-muted-foreground`}
                  />
                  {isSearching && <span className="absolute right-4 top-3.5 text-xs text-muted-foreground">Mencari...</span>}
                  
                  {showDropdown && searchResults.length > 0 && (
                    <div className="absolute z-10 w-full mt-1 bg-background border border-border max-h-60 overflow-y-auto shadow-lg">
                      {searchResults.map((opt) => (
                        <div
                          key={opt.id}
                          className="px-4 py-2 text-sm hover:bg-foreground/5 cursor-pointer border-b border-border/50 last:border-0"
                          onClick={() => selectDestination(opt)}
                        >
                          <p className="font-medium">{opt.subdistrict_name}, {opt.city_name}</p>
                          <p className="text-xs text-muted-foreground">{opt.province_name} - {opt.zip_code}</p>
                        </div>
                      ))}
                    </div>
                  )}
                  {errors.destination && <p className="text-destructive text-xs mt-1">{errors.destination}</p>}
                </div>

                {form.destinationId > 0 && (
                  <div className="grid grid-cols-2 gap-3 opacity-70">
                    <input disabled type="text" value={form.province} className="w-full bg-secondary/50 border border-border px-4 py-3 text-sm cursor-not-allowed" />
                    <input disabled type="text" value={form.postalCode} className="w-full bg-secondary/50 border border-border px-4 py-3 text-sm cursor-not-allowed" />
                  </div>
                )}

                <div>
                  <input
                    type="text"
                    placeholder="Nama jalan / Gedung / Nomor rumah"
                    value={form.streetAddress}
                    onChange={(e) => updateField("streetAddress", e.target.value)}
                    className={inputClass("streetAddress")}
                  />
                  {errors.streetAddress && <p className="text-destructive text-xs mt-1">{errors.streetAddress}</p>}
                </div>
                <div>
                  <input
                    type="text"
                    placeholder="Detail lainnya — blok, unit, patokan (opsional)"
                    value={form.addressDetail}
                    onChange={(e) => updateField("addressDetail", e.target.value)}
                    className="w-full bg-transparent border border-border px-4 py-3 text-sm outline-none focus:border-foreground transition-colors placeholder:text-muted-foreground"
                  />
                </div>
              </div>
            </div>

            {/* Shipping */}
            <div>
              <h2 className="text-xs tracking-[0.2em] uppercase mb-4">Metode Pengiriman (JNE)</h2>
              {!form.destinationId ? (
                <p className="text-sm text-muted-foreground border border-border px-4 py-3">
                  Pilih kecamatan/kota pengiriman terlebih dahulu untuk melihat ongkos kirim.
                </p>
              ) : shippingRates.length === 0 ? (
                <p className="text-sm text-muted-foreground border border-border px-4 py-3">
                  Memuat opsi pengiriman...
                </p>
              ) : (
                <div className="space-y-2">
                  {shippingRates.map((rate) => (
                    <label
                      key={rate.service}
                      className={`flex items-center justify-between border px-4 py-3 cursor-pointer transition-colors ${
                        form.selectedShipping === rate.service
                          ? "border-foreground bg-foreground/5"
                          : "border-border hover:border-foreground/30"
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <input
                          type="radio"
                          name="shipping"
                          value={rate.service}
                          checked={form.selectedShipping === rate.service}
                          onChange={() => updateField("selectedShipping", rate.service)}
                          className="accent-foreground"
                        />
                        <div>
                          <span className="text-sm block">JNE {rate.service}</span>
                          <span className="text-xs text-muted-foreground">{rate.description} ({rate.etd})</span>
                        </div>
                      </div>
                      <span className="text-sm font-heading">{formatPrice(rate.cost)}</span>
                    </label>
                  ))}
                </div>
              )}
              {errors.shipping && <p className="text-destructive text-xs mt-1">{errors.shipping}</p>}
            </div>

            {/* Special Instructions */}
            <div>
              <h2 className="text-xs tracking-[0.2em] uppercase mb-4">Catatan Khusus</h2>
              <textarea
                placeholder="Catatan untuk pesanan (opsional)"
                rows={3}
                value={form.specialInstructions}
                onChange={(e) => updateField("specialInstructions", e.target.value)}
                className="w-full bg-transparent border border-border px-4 py-3 text-sm outline-none focus:border-foreground transition-colors placeholder:text-muted-foreground resize-none"
              />
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 text-xs tracking-[0.2em] uppercase bg-foreground text-background hover:bg-foreground/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? "Memproses..." : "Bayar Sekarang"}
            </button>
          </form>

          {/* Order Summary */}
          <div className="border border-border p-5 sm:p-6 h-fit">
            <h2 className="text-xs tracking-[0.2em] uppercase mb-6">Ringkasan Pesanan</h2>
            <div className="space-y-4">
              {items.map((item) => (
                <div key={item.variantId} className="flex justify-between text-sm">
                  <div>
                    <span>{item.name}</span>
                    <span className="text-muted-foreground"> × {item.quantity}</span>
                    <p className="text-xs text-muted-foreground">Size: {item.size}</p>
                  </div>
                  <span className="shrink-0">{formatPrice(item.price * item.quantity)}</span>
                </div>
              ))}
            </div>
            <div className="border-t border-border mt-6 pt-4 space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Subtotal</span>
                <span>{formatPrice(subtotal)}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Ongkos Kirim</span>
                <span>{selectedRate ? formatPrice(shippingCost) : <span className="text-muted-foreground text-xs">—</span>}</span>
              </div>
              <div className="flex justify-between pt-2 border-t border-border font-heading">
                <span className="text-xs tracking-[0.2em] uppercase">Total</span>
                <span>{formatPrice(total)}</span>
              </div>
            </div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
}
