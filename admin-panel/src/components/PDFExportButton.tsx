// src/components/PDFExportButton.tsx
import { useState } from "react";
import { supabase } from "../lib/supabase";
import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";
import dayjs from "dayjs";
import { netPaid } from "../lib/money";

export default function PDFExportButton() {
  const [selectedMonth, setSelectedMonth] = useState(dayjs().format("YYYY-MM"));
  const [downloading, setDownloading] = useState(false);

  const handleExport = async () => {
    setDownloading(true);
    const [year, month] = selectedMonth.split("-");
    const start = dayjs(`${year}-${month}-01`).startOf("month");
    const end = dayjs(start).endOf("month");

    // Fulfilled orders come in three terminal statuses, not just "completed".
    const { data } = await supabase
      .from("orders")
      .select("id, order_number, created_at, total, refund_amount, profiles!user_id(name, email)")
      .in("status", ["completed", "delivered", "picked up"])
      .gte("created_at", start.toISOString())
      .lte("created_at", end.toISOString())
      .order("created_at", { ascending: true });

    const orders = (data ?? []).map((row) => {
      const profile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
      return {
        orderId: row.order_number || row.id.slice(0, 8),
        customerName: profile?.name || profile?.email || "N/A",
        total: netPaid(row).toFixed(2),
        date: row.created_at ? dayjs(row.created_at).format("MMM D, YYYY") : "—",
      };
    });

    const doc = new jsPDF();
    doc.text(`Completed Orders – ${start.format("MMMM YYYY")}`, 14, 15);
    autoTable(doc, {
      head: [["Order ID", "Customer", "Total ($)", "Date"]],
      body: orders.map(o => [o.orderId, o.customerName, o.total, o.date]),
      startY: 20,
    });

    const fileName = `Completed_Orders_${start.format("MMMM_YYYY")}.pdf`;
    doc.save(fileName);
    setDownloading(false);
  };

  return (
    <div className="flex items-center gap-3 mt-4">
      <input
        type="month"
        value={selectedMonth}
        onChange={(e) => setSelectedMonth(e.target.value)}
        className="border border-gray-300 rounded px-3 py-2 text-sm"
      />
      <button
        onClick={handleExport}
        disabled={downloading}
        className="bg-amber-600 text-white px-4 py-2 rounded hover:bg-amber-700 disabled:opacity-50"
      >
        {downloading ? "Generating..." : "Download PDF"}
      </button>
    </div>
  );
}
