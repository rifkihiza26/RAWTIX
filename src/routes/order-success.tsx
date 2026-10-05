import { createFileRoute, Link, useSearch } from "@tanstack/react-router";
import { Header } from "@/components/layout/Header";
import { Footer } from "@/components/layout/Footer";
import { z } from "zod";
import { useState, useEffect, useRef } from "react";
import { supabase } from "@/integrations/supabase/client";
import { getOrderByNumber, submitPaymentProof } from "@/utils/orders.functions";
import { formatPrice } from "@/components/product/ProductCard";
import { toast } from "sonner";

const searchSchema = z.object({
  order: z.string().optional(),
});

export const Route = createFileRoute("/order-success")({
  validateSearch: (search) => searchSchema.parse(search),
  component: OrderSuccessPage,
});

function OrderSuccessPage() {
  const { order: orderNumber } = useSearch({ from: "/order-success" });
  const [orderData, setOrderData] = useState<{
    order_number: string;
    total: number;
    status: string;
    payment_proof_url: string | null;
    payment_proof_submitted_at: string | null;
  } | null>(null);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [proofSubmitted, setProofSubmitted] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!orderNumber) {
      setLoading(false);
      return;
    }
    getOrderByNumber({ data: { orderNumber } })
      .then((data) => {
        setOrderData(data);
        if (data?.payment_proof_url) setProofSubmitted(true);
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [orderNumber]);

  if (!orderNumber) {
    return (
      <div className="min-h-screen bg-background text-foreground">
        <Header />
        <div className="pt-[72px] flex items-center justify-center py-32">
          <div className="text-center">
            <p className="text-muted-foreground text-sm">
              Tidak ada pesanan ditemukan.
            </p>
            <Link
              to="/shop"
              className="mt-4 inline-block text-xs tracking-[0.2em] uppercase border-b border-foreground pb-1"
            >
              Belanja
            </Link>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background text-foreground">
      <Header />
      <main className="pt-[72px] flex items-center justify-center py-20 px-6">
        <div className="max-w-lg w-full space-y-8">
          {/* Confirmation header */}
          <div className="text-center space-y-4">
            <div className="w-12 h-12 mx-auto border border-foreground/30 flex items-center justify-center">
              <span className="text-foreground text-lg">✓</span>
            </div>
            <h1 className="font-heading text-xs tracking-[0.3em] uppercase">
              Pesanan Diterima
            </h1>
            <p className="text-sm text-muted-foreground leading-relaxed">
              Terima kasih telah berbelanja di RAWTIX. Pembayaran Anda akan diproses secara otomatis oleh sistem kami.
            </p>
          </div>

          {/* Order summary */}
          <div className="border border-border p-6 space-y-3">
            <div className="flex justify-between text-sm">
              <span className="text-muted-foreground">Nomor Pesanan</span>
              <span className="font-heading tracking-wide">{orderNumber}</span>
            </div>
            {orderData && (
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Total Pembayaran</span>
                <span className="font-heading tracking-wide">
                  {formatPrice(orderData.total)}
                </span>
              </div>
            )}
            <div className="flex justify-between text-sm">
              <span className="text-muted-foreground">Status</span>
              <span className="text-xs tracking-[0.15em] uppercase">
                {orderData?.status === 'paid' ? "Lunas" : "Menunggu Verifikasi Pembayaran"}
              </span>
            </div>
          </div>

          {/* Payment Status Info */}
          <div className="border border-border p-6 text-center space-y-2">
            <p className="text-sm text-foreground">
              Status pesanan akan diupdate secara otomatis.
            </p>
            <p className="text-xs text-muted-foreground">
              Jika Anda mengalami kendala pembayaran, silakan hubungi kami melalui WhatsApp.
            </p>
          </div>

          {/* Contact */}
          <p className="text-xs text-muted-foreground text-center">
            Hubungi kami via WhatsApp di{" "}
            <a
              href="https://wa.me/6285719636329"
              target="_blank"
              rel="noopener noreferrer"
              className="text-foreground hover:text-muted-foreground transition-colors border-b border-foreground/30"
            >
              +62 857-1963-6329
            </a>{" "}
            jika ada pertanyaan.
          </p>

          <div className="text-center">
            <Link
              to="/shop"
              className="inline-block px-8 py-3 text-xs tracking-[0.25em] uppercase border border-foreground/30 hover:border-foreground hover:bg-foreground hover:text-background transition-all duration-300"
            >
              Lanjut Belanja
            </Link>
          </div>
        </div>
      </main>
      <Footer />
    </div>
  );
}
