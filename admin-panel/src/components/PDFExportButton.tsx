// src/components/PDFExportButton.tsx
import { useState } from "react";
import { collection, getDocs, query, where } from "firebase/firestore";
import { db } from "../firebase";
import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";
import dayjs from "dayjs";

export default function PDFExportButton() {
  const [selectedMonth, setSelectedMonth] = useState(dayjs().format("YYYY-MM"));
  const [downloading, setDownloading] = useState(false);

  const handleExport = async () => {
    setDownloading(true);
    const [year, month] = selectedMonth.split("-");
    const start = dayjs(`${year}-${month}-01`).startOf("month");
    const end = dayjs(start).endOf("month");

    const ordersRef = collection(db, "orders");
    const q = query(
      ordersRef,
      where("status", "==", "completed"),
      where("createdAt", ">=", start.toDate()),
      where("createdAt", "<=", end.toDate())
    );

    const snapshot = await getDocs(q);

    const orders = snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        orderId: data.orderId || doc.id,
        customerName: data.customerName || "N/A",
        total: data?.pricing?.total?.toFixed(2) || data?.total?.toFixed(2) || "0.00",
        date: data?.createdAt?.toDate
          ? dayjs(data.createdAt.toDate()).format("MMM D, YYYY")
          : "—",
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
