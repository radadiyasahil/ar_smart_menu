import {
  Download,
  FileText,
  Printer,
  ShieldCheck,
  X,
} from 'lucide-react'
import { useState } from 'react'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { adminService } from '@/services/adminService'
import type { SubscriptionInvoice } from '@/types/admin'

interface GstInvoiceModalProps {
  invoice: SubscriptionInvoice
  onClose: () => void
}

export function GstInvoiceModal({ invoice, onClose }: GstInvoiceModalProps) {
  const [isOpeningPrint, setIsOpeningPrint] = useState(false)

  const handlePrint = () => {
    setIsOpeningPrint(true)
    const url = adminService.getSubscriptionInvoiceHtmlUrl(invoice.subscriptionId)
    const win = window.open(url, '_blank')
    if (win) {
      win.focus()
    }
    setTimeout(() => setIsOpeningPrint(false), 500)
  }

  const handleDownloadHtml = () => {
    const url = adminService.getSubscriptionInvoiceHtmlUrl(invoice.subscriptionId)
    const a = document.createElement('a')
    a.href = url
    a.download = `GST_Invoice_${invoice.invoiceNumber}.html`
    a.target = '_blank'
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm">
      <div className="relative flex max-h-[92vh] w-full max-w-4xl flex-col rounded-xl border border-border bg-card shadow-2xl">
        {/* Top Action Bar */}
        <div className="flex items-center justify-between border-b border-border px-6 py-4">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10 text-primary">
              <FileText className="h-5 w-5" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-foreground">
                GST Tax Invoice — {invoice.invoiceNumber}
              </h2>
              <p className="text-xs text-muted-foreground">
                Statutory Return & Government Audit Compliant Document
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={handleDownloadHtml}
              className="gap-1.5"
            >
              <Download className="h-4 w-4" />
              Download
            </Button>

            <Button
              variant="default"
              size="sm"
              onClick={handlePrint}
              disabled={isOpeningPrint}
              className="gap-1.5 bg-blue-600 hover:bg-blue-700 text-white"
            >
              <Printer className="h-4 w-4" />
              Print / Save PDF
            </Button>

            <Button
              variant="ghost"
              size="icon"
              onClick={onClose}
              className="h-8 w-8 text-muted-foreground hover:text-foreground"
            >
              <X className="h-5 w-5" />
            </Button>
          </div>
        </div>

        {/* Invoice Body (Paper Style Preview) */}
        <div className="flex-1 overflow-y-auto p-6">
          <div className="mx-auto max-w-3xl rounded-lg border border-slate-200 bg-white p-8 text-slate-900 shadow-sm">
            {/* Header */}
            <div className="flex items-start justify-between border-b-2 border-slate-900 pb-5">
              <div>
                <span className="text-2xl font-black tracking-tight text-blue-600">
                  AR SMART MENU
                </span>
                <p className="text-xs uppercase tracking-wider text-slate-500">
                  Interactive 3D AR Dining & Kitchen Ordering Platform
                </p>
                <p className="mt-1 text-sm font-semibold text-slate-800">
                  {invoice.supplierLegalName}
                </p>
              </div>

              <div className="text-right">
                <span className="inline-block rounded bg-slate-900 px-3 py-1 text-sm font-bold tracking-wide text-white">
                  TAX INVOICE
                </span>
                <p className="mt-1 text-[11px] text-slate-500">
                  Rule 46 of CGST Rules, 2017
                </p>
                <Badge variant="success" className="mt-1.5 border-emerald-500 text-emerald-700 bg-emerald-50 text-[11px]">
                  Original for Recipient
                </Badge>
              </div>
            </div>

            {/* Invoice Meta Grid */}
            <div className="mt-4 grid grid-cols-4 gap-3 rounded-md border border-slate-200 bg-slate-50 p-3 text-xs">
              <div>
                <p className="text-[10px] uppercase font-medium text-slate-500">Invoice No.</p>
                <p className="font-bold text-slate-900">{invoice.invoiceNumber}</p>
              </div>
              <div>
                <p className="text-[10px] uppercase font-medium text-slate-500">Invoice Date</p>
                <p className="font-bold text-slate-900">
                  {new Date(invoice.invoiceDate).toLocaleDateString('en-IN', {
                    day: '2-digit',
                    month: 'short',
                    year: 'numeric',
                  })}
                </p>
              </div>
              <div>
                <p className="text-[10px] uppercase font-medium text-slate-500">Place of Supply</p>
                <p className="font-bold text-slate-900">{invoice.placeOfSupply}</p>
              </div>
              <div>
                <p className="text-[10px] uppercase font-medium text-slate-500">Reverse Charge</p>
                <p className="font-bold text-slate-900">
                  {invoice.isReverseCharge ? 'Yes' : 'No'}
                </p>
              </div>
            </div>

            {/* Billed By & Billed To */}
            <div className="mt-6 grid grid-cols-2 gap-4 text-xs">
              <div className="rounded-md border border-slate-200 p-4 bg-slate-50/50">
                <p className="text-[11px] font-bold uppercase tracking-wider text-blue-700 border-b border-slate-200 pb-1.5 mb-2">
                  Supplier (Billed By)
                </p>
                <p className="font-bold text-sm text-slate-900">{invoice.supplierLegalName}</p>
                <p className="mt-0.5 text-slate-600">{invoice.supplierAddress}, {invoice.supplierCity}</p>
                <p className="text-slate-600">
                  State: {invoice.supplierState} (Code: {invoice.supplierStateCode})
                </p>
                <p className="text-slate-600 mt-1">Email: {invoice.supplierEmail}</p>
                <div className="mt-2 inline-block rounded bg-emerald-50 px-2 py-0.5 font-bold text-emerald-800 border border-emerald-200">
                  GSTIN: {invoice.supplierGstin}
                </div>
                <p className="text-[11px] text-slate-500 mt-0.5">PAN: {invoice.supplierPan}</p>
              </div>

              <div className="rounded-md border border-slate-200 p-4 bg-slate-50/50">
                <p className="text-[11px] font-bold uppercase tracking-wider text-blue-700 border-b border-slate-200 pb-1.5 mb-2">
                  Recipient (Billed To)
                </p>
                <p className="font-bold text-sm text-slate-900">{invoice.recipientBusinessName}</p>
                {invoice.recipientOwnerName && (
                  <p className="mt-0.5 text-slate-700 font-medium">
                    Attn: {invoice.recipientOwnerName} ({invoice.recipientMobile ?? ''})
                  </p>
                )}
                <p className="text-slate-600">{invoice.recipientAddress}, {invoice.recipientCity}</p>
                <p className="text-slate-600">
                  State: {invoice.recipientState} (Code: {invoice.recipientStateCode})
                </p>
                {invoice.recipientGstin ? (
                  <div className="mt-2 inline-block rounded bg-emerald-50 px-2 py-0.5 font-bold text-emerald-800 border border-emerald-200">
                    Recipient GSTIN: {invoice.recipientGstin}
                  </div>
                ) : (
                  <p className="mt-2 text-slate-500 italic">
                    GST Status: Unregistered Person (B2C)
                  </p>
                )}
              </div>
            </div>

            {/* Itemized Table */}
            <div className="mt-6 overflow-hidden rounded-md border border-slate-200">
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-900 text-white">
                  <tr>
                    <th className="py-2.5 px-3 font-semibold">#</th>
                    <th className="py-2.5 px-3 font-semibold">Description of Service</th>
                    <th className="py-2.5 px-3 font-semibold">SAC Code</th>
                    <th className="py-2.5 px-3 font-semibold">Period</th>
                    <th className="py-2.5 px-3 font-semibold text-right">Taxable (₹)</th>
                    <th className="py-2.5 px-3 font-semibold text-right">CGST</th>
                    <th className="py-2.5 px-3 font-semibold text-right">SGST</th>
                    <th className="py-2.5 px-3 font-semibold text-right">Total (₹)</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-200">
                  <tr>
                    <td className="py-3 px-3">1</td>
                    <td className="py-3 px-3">
                      <p className="font-bold text-slate-900">{invoice.planName}</p>
                      <p className="text-[11px] text-slate-500">
                        SaaS Platform Subscription & Interactive 3D AR Visualizer
                      </p>
                    </td>
                    <td className="py-3 px-3 font-mono">{invoice.sacCode}</td>
                    <td className="py-3 px-3 whitespace-nowrap">
                      {new Date(invoice.startsAt).toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: '2-digit' })} –{' '}
                      {new Date(invoice.endsAt).toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: '2-digit' })}
                    </td>
                    <td className="py-3 px-3 text-right font-medium">₹{invoice.baseAmountRupees.toFixed(2)}</td>
                    <td className="py-3 px-3 text-right">
                      ₹{invoice.cgstRupees.toFixed(2)}{' '}
                      <span className="text-[10px] text-slate-500">({invoice.cgstRate}%)</span>
                    </td>
                    <td className="py-3 px-3 text-right">
                      ₹{invoice.sgstRupees.toFixed(2)}{' '}
                      <span className="text-[10px] text-slate-500">({invoice.sgstRate}%)</span>
                    </td>
                    <td className="py-3 px-3 text-right font-bold text-slate-900">
                      ₹{invoice.totalAmountRupees.toFixed(2)}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            {/* Bottom Summary Grid */}
            <div className="mt-5 grid grid-cols-2 gap-6 items-start text-xs">
              {/* Payment Details */}
              <div className="rounded-md border border-slate-200 bg-slate-50 p-4">
                <p className="font-bold uppercase tracking-wider text-slate-800 text-[11px] mb-2">
                  Payment & Transaction Details
                </p>
                <div className="space-y-1 text-slate-700">
                  <p><strong>Payment Mode:</strong> {invoice.paymentMethod}</p>
                  <p className="font-mono text-[11px]"><strong>Transaction ID:</strong> {invoice.transactionRef || 'N/A'}</p>
                  <p>
                    <strong>Payment Status:</strong>{' '}
                    <span className="font-bold text-emerald-700">PAID / {invoice.paymentStatus.toUpperCase()}</span>
                  </p>
                  <p>
                    <strong>Transaction Date:</strong>{' '}
                    {new Date(invoice.paidAt).toLocaleDateString('en-IN', {
                      day: '2-digit',
                      month: 'short',
                      year: 'numeric',
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </p>
                </div>
              </div>

              {/* Totals Table */}
              <div className="rounded-md border border-slate-200 overflow-hidden text-xs">
                <div className="flex justify-between px-3 py-2 border-b border-slate-100">
                  <span className="text-slate-600">Taxable Amount:</span>
                  <span className="font-semibold text-slate-900">₹{invoice.baseAmountRupees.toFixed(2)}</span>
                </div>
                {invoice.igstRate > 0 ? (
                  <div className="flex justify-between px-3 py-2 border-b border-slate-100">
                    <span className="text-slate-600">Integrated GST (IGST @ {invoice.igstRate}%):</span>
                    <span className="font-semibold text-slate-900">₹{invoice.igstRupees.toFixed(2)}</span>
                  </div>
                ) : (
                  <>
                    <div className="flex justify-between px-3 py-2 border-b border-slate-100">
                      <span className="text-slate-600">Central GST (CGST @ {invoice.cgstRate}%):</span>
                      <span className="font-semibold text-slate-900">₹{invoice.cgstRupees.toFixed(2)}</span>
                    </div>
                    <div className="flex justify-between px-3 py-2 border-b border-slate-100">
                      <span className="text-slate-600">State GST (SGST @ {invoice.sgstRate}%):</span>
                      <span className="font-semibold text-slate-900">₹{invoice.sgstRupees.toFixed(2)}</span>
                    </div>
                  </>
                )}
                <div className="flex justify-between px-3 py-2 border-b border-slate-100 bg-slate-50">
                  <span className="text-slate-700 font-medium">Total GST (18%):</span>
                  <span className="font-semibold text-slate-900">₹{invoice.gstRupees.toFixed(2)}</span>
                </div>
                <div className="flex justify-between px-3 py-2.5 bg-slate-900 text-white font-bold text-sm">
                  <span>Grand Total:</span>
                  <span>₹{invoice.totalAmountRupees.toFixed(2)}</span>
                </div>
              </div>
            </div>

            {/* Amount in words */}
            <div className="mt-4 rounded border-l-4 border-blue-600 bg-slate-50 p-3 text-xs font-semibold text-slate-800">
              Amount in Words: <span className="font-bold">{invoice.amountInWords}</span>
            </div>

            {/* Declarations & Signatures */}
            <div className="mt-6 grid grid-cols-3 gap-4 border-t border-slate-200 pt-4 text-[11px] text-slate-500">
              <div className="col-span-2 space-y-1">
                <p className="font-bold text-slate-700">Declarations & Notes:</p>
                <p>1. Certified that the particulars given above are true and correct.</p>
                <p>2. Electronic Tax Invoice compliant with Section 31 of CGST Act, 2017. Valid for Input Tax Credit (ITC) claiming and GST return filing.</p>
                <p>3. This is a computer-generated invoice and requires no physical signature.</p>
              </div>

              <div className="rounded border border-dashed border-slate-300 p-3 text-center">
                <p className="text-[10px] text-slate-400">For AR Smart Menu Technologies Pvt. Ltd.</p>
                <div className="mt-5 border-t border-slate-300 pt-1 text-[11px] font-bold text-blue-700">
                  Authorized Signatory
                  <span className="block text-[9px] font-normal text-emerald-600">✓ Digitally Signed & Verified</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between border-t border-border px-6 py-3 text-xs text-muted-foreground">
          <span className="flex items-center gap-1.5 text-emerald-600 font-medium">
            <ShieldCheck className="h-4 w-4" />
            Verified Government Tax Invoice
          </span>
          <Button variant="ghost" size="sm" onClick={onClose}>
            Close
          </Button>
        </div>
      </div>
    </div>
  )
}
