import {
  Calendar,
  Check,
  CreditCard,
  Download,
  ExternalLink,
  FileSpreadsheet,
  FileText,
  Filter,
  IndianRupee,
  Layers,
  Printer,
  RefreshCw,
  Search,
  ShieldCheck,
  TrendingUp,
  X,
} from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'

import { GstInvoiceModal } from '@/components/billing/GstInvoiceModal'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Skeleton } from '@/components/ui/skeleton'
import { adminService } from '@/services/adminService'
import type { SubscriptionHistoryItem, SubscriptionInvoice } from '@/types/admin'

export function SubscriptionHistoryPage() {
  const [history, setHistory] = useState<SubscriptionHistoryItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  // Filters
  const [searchQuery, setSearchQuery] = useState('')
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'expired' | 'cancelled'>('all')

  // Invoice modal
  const [selectedInvoice, setSelectedInvoice] = useState<SubscriptionInvoice | null>(null)
  const [loadingInvoiceId, setLoadingInvoiceId] = useState<string | null>(null)

  const fetchHistory = async () => {
    try {
      setLoading(true)
      setError(null)
      const data = await adminService.listSubscriptionHistory()
      setHistory(data)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load subscription history')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchHistory()
  }, [])

  // Filtered items
  const filteredHistory = useMemo(() => {
    return history.filter((item) => {
      // Status filter
      if (statusFilter === 'active' && (!item.isActive || item.status !== 0)) return false
      if (statusFilter === 'expired' && item.status !== 3) return false
      if (statusFilter === 'cancelled' && item.status !== 2) return false

      // Search filter
      if (searchQuery.trim()) {
        const query = searchQuery.toLowerCase().trim()
        const matchesInvoice = item.invoiceNumber?.toLowerCase().includes(query) ?? false
        const matchesBusiness = item.businessName.toLowerCase().includes(query)
        const matchesOwner = item.ownerName?.toLowerCase().includes(query) ?? false
        const matchesPhone = item.ownerMobile?.includes(query) ?? false
        const matchesPlan = item.planName.toLowerCase().includes(query)
        const matchesTxn = item.transactionRef?.toLowerCase().includes(query) ?? false

        if (!matchesInvoice && !matchesBusiness && !matchesOwner && !matchesPhone && !matchesPlan && !matchesTxn) {
          return false
        }
      }

      return true
    })
  }, [history, searchQuery, statusFilter])

  // Summary Metrics
  const metrics = useMemo(() => {
    let totalRevenue = 0
    let totalGst = 0
    let activeCount = 0

    history.forEach((h) => {
      totalRevenue += h.totalPriceRupees
      totalGst += h.gstRupees
      if (h.isActive && h.status === 0) activeCount++
    })

    return {
      totalRevenue,
      totalGst,
      activeCount,
      totalTransactions: history.length,
    }
  }, [history])

  const handleOpenInvoice = async (subscriptionId: string) => {
    try {
      setLoadingInvoiceId(subscriptionId)
      const inv = await adminService.getSubscriptionInvoice(subscriptionId)
      setSelectedInvoice(inv)
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to load GST invoice')
    } finally {
      setLoadingInvoiceId(null)
    }
  }

  const handlePrintDirect = (subscriptionId: string) => {
    const url = adminService.getSubscriptionInvoiceHtmlUrl(subscriptionId)
    window.open(url, '_blank')
  }

  const handleExportCsv = () => {
    if (filteredHistory.length === 0) {
      alert('No transactions available to export')
      return
    }

    const headers = [
      'Invoice Number',
      'Invoice Date',
      'Business Name',
      'Customer GSTIN',
      'City',
      'Owner Phone',
      'Plan Name',
      'Duration Days',
      'Starts At',
      'Ends At',
      'Taxable Amount (INR)',
      'GST Amount (INR)',
      'Total Amount (INR)',
      'Payment Mode',
      'Transaction Ref',
      'Status',
    ]

    const rows = filteredHistory.map((item) => [
      `"${item.invoiceNumber ?? ''}"`,
      `"${new Date(item.invoiceDate ?? item.startsAt).toLocaleDateString('en-IN')}"`,
      `"${item.businessName.replace(/"/g, '""')}"`,
      `"${item.customerGstNumber ?? 'URP'}"`,
      `"${item.customerCity ?? ''}"`,
      `"${item.ownerMobile ?? ''}"`,
      `"${item.planName.replace(/"/g, '""')}"`,
      item.durationDays,
      `"${new Date(item.startsAt).toLocaleDateString('en-IN')}"`,
      `"${new Date(item.endsAt).toLocaleDateString('en-IN')}"`,
      item.basePriceRupees.toFixed(2),
      item.gstRupees.toFixed(2),
      item.totalPriceRupees.toFixed(2),
      `"${item.paymentMethod ?? 'UPI'}"`,
      `"${item.transactionRef ?? ''}"`,
      item.status === 0 ? 'Active' : item.status === 2 ? 'Cancelled' : 'Expired',
    ])

    const csvContent = [headers.join(','), ...rows.map((r) => r.join(','))].join('\n')
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `ARSmartMenu_GST_Subscription_Invoices_${new Date().toISOString().slice(0, 10)}.csv`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground flex items-center gap-2">
            <CreditCard className="h-6 w-6 text-primary" />
            Subscription & Invoices (GST Audit)
          </h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            Complete transaction ledger with downloadable Indian GST Tax Invoices for returns & government audit
          </p>
        </div>

        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={fetchHistory}
            disabled={loading}
            className="gap-1.5"
          >
            <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </Button>

          <Button
            variant="default"
            size="sm"
            onClick={handleExportCsv}
            disabled={loading || filteredHistory.length === 0}
            className="gap-1.5 bg-emerald-600 hover:bg-emerald-700 text-white"
          >
            <FileSpreadsheet className="h-4 w-4" />
            Export GST Return CSV
          </Button>
        </div>
      </div>

      {/* Metrics Cards */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-xs font-semibold uppercase text-muted-foreground">
              Total Subscription Revenue
            </CardTitle>
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-emerald-500/10 text-emerald-500">
              <IndianRupee className="h-4 w-4" />
            </div>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">
              ₹{metrics.totalRevenue.toLocaleString('en-IN', { maximumFractionDigits: 0 })}
            </div>
            <p className="text-xs text-muted-foreground mt-1">Across all paid subscriptions</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-xs font-semibold uppercase text-muted-foreground">
              Total GST Collected (18%)
            </CardTitle>
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-500/10 text-blue-500">
              <ShieldCheck className="h-4 w-4" />
            </div>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">
              ₹{metrics.totalGst.toLocaleString('en-IN', { maximumFractionDigits: 0 })}
            </div>
            <p className="text-xs text-muted-foreground mt-1">Ready for GSTR-1 / GSTR-3B audit</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-xs font-semibold uppercase text-muted-foreground">
              Active Subscriptions
            </CardTitle>
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-indigo-500/10 text-indigo-500">
              <TrendingUp className="h-4 w-4" />
            </div>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">
              {metrics.activeCount}
            </div>
            <p className="text-xs text-muted-foreground mt-1">Restaurants currently live</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-xs font-semibold uppercase text-muted-foreground">
              Total Invoices Issued
            </CardTitle>
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-amber-500/10 text-amber-500">
              <FileText className="h-4 w-4" />
            </div>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">
              {metrics.totalTransactions}
            </div>
            <p className="text-xs text-muted-foreground mt-1">Past transactions logged</p>
          </CardContent>
        </Card>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between rounded-lg border border-border bg-card p-4">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Search by Invoice #, Restaurant, Phone, Txn ID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-9 h-9"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
            >
              <X className="h-4 w-4" />
            </button>
          )}
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs text-muted-foreground font-medium flex items-center gap-1">
            <Filter className="h-3.5 w-3.5" /> Status:
          </span>
          <div className="flex rounded-md border border-border bg-background p-0.5 text-xs">
            {(['all', 'active', 'expired', 'cancelled'] as const).map((status) => (
              <button
                key={status}
                onClick={() => setStatusFilter(status)}
                className={`rounded px-2.5 py-1 font-medium capitalize transition-colors ${
                  statusFilter === status
                    ? 'bg-primary text-primary-foreground'
                    : 'text-muted-foreground hover:text-foreground'
                }`}
              >
                {status}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Transactions & Invoices Table */}
      <Card>
        <CardContent className="p-0">
          {loading ? (
            <div className="space-y-3 p-6">
              {[1, 2, 3, 4, 5].map((i) => (
                <Skeleton key={i} className="h-12 w-full" />
              ))}
            </div>
          ) : error ? (
            <div className="p-8 text-center text-destructive">
              <p>{error}</p>
              <Button variant="outline" size="sm" onClick={fetchHistory} className="mt-3">
                Try Again
              </Button>
            </div>
          ) : filteredHistory.length === 0 ? (
            <div className="p-12 text-center text-muted-foreground">
              <FileText className="mx-auto h-10 w-10 text-muted-foreground/40 mb-2" />
              <p className="font-medium">No subscription transactions found</p>
              <p className="text-xs mt-1">Try adjusting your search or status filter</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="border-b border-border bg-muted/50 text-muted-foreground">
                  <tr>
                    <th className="py-3 px-4 font-semibold">Invoice No.</th>
                    <th className="py-3 px-4 font-semibold">Restaurant & Contact</th>
                    <th className="py-3 px-4 font-semibold">Plan & Period</th>
                    <th className="py-3 px-4 font-semibold text-right">Taxable (₹)</th>
                    <th className="py-3 px-4 font-semibold text-right">GST (18%)</th>
                    <th className="py-3 px-4 font-semibold text-right">Total (₹)</th>
                    <th className="py-3 px-4 font-semibold">Payment / Txn ID</th>
                    <th className="py-3 px-4 font-semibold">Status</th>
                    <th className="py-3 px-4 font-semibold text-right">GST Invoice Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {filteredHistory.map((item) => (
                    <tr key={item.id} className="hover:bg-muted/30 transition-colors">
                      {/* Invoice No */}
                      <td className="py-3.5 px-4 font-mono font-medium text-foreground">
                        <div className="flex items-center gap-1.5">
                          <FileText className="h-3.5 w-3.5 text-blue-500 shrink-0" />
                          <span>{item.invoiceNumber || `INV-${item.startsAt.slice(0, 7).replace('-', '')}-${item.id.slice(0, 4)}`}</span>
                        </div>
                        <span className="text-[10px] text-muted-foreground block pl-5">
                          {new Date(item.invoiceDate ?? item.startsAt).toLocaleDateString('en-IN', {
                            day: '2-digit',
                            month: 'short',
                            year: 'numeric',
                          })}
                        </span>
                      </td>

                      {/* Business & Contact */}
                      <td className="py-3.5 px-4">
                        <p className="font-semibold text-foreground text-sm">{item.businessName}</p>
                        <p className="text-[11px] text-muted-foreground">
                          {item.ownerName ? `${item.ownerName} • ` : ''}
                          {item.ownerMobile ?? 'No mobile'}
                        </p>
                        {item.customerGstNumber && (
                          <span className="inline-block mt-0.5 rounded bg-emerald-500/10 px-1.5 py-0.2 text-[10px] font-medium text-emerald-600">
                            GSTIN: {item.customerGstNumber}
                          </span>
                        )}
                      </td>

                      {/* Plan & Period */}
                      <td className="py-3.5 px-4">
                        <Badge variant="outline" className="font-medium text-xs">
                          {item.planName}
                        </Badge>
                        <p className="text-[11px] text-muted-foreground mt-1">
                          {new Date(item.startsAt).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })} –{' '}
                          {new Date(item.endsAt).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}
                        </p>
                      </td>

                      {/* Taxable */}
                      <td className="py-3.5 px-4 text-right font-medium text-foreground">
                        ₹{item.basePriceRupees.toFixed(2)}
                      </td>

                      {/* GST */}
                      <td className="py-3.5 px-4 text-right text-muted-foreground">
                        ₹{item.gstRupees.toFixed(2)}
                      </td>

                      {/* Total */}
                      <td className="py-3.5 px-4 text-right font-bold text-foreground">
                        ₹{item.totalPriceRupees.toFixed(2)}
                      </td>

                      {/* Payment info */}
                      <td className="py-3.5 px-4">
                        <span className="rounded bg-muted px-1.5 py-0.5 text-[10px] font-medium text-foreground">
                          {item.paymentMethod || 'UPI'}
                        </span>
                        <p className="font-mono text-[10px] text-muted-foreground mt-0.5 truncate max-w-[140px]" title={item.transactionRef ?? ''}>
                          {item.transactionRef || '—'}
                        </p>
                      </td>

                      {/* Status */}
                      <td className="py-3.5 px-4">
                        {item.status === 0 && item.isActive ? (
                          <Badge variant="outline" className="border-emerald-500 text-emerald-600 bg-emerald-500/10">
                            Active
                          </Badge>
                        ) : item.status === 2 ? (
                          <Badge variant="outline" className="border-amber-500 text-amber-600 bg-amber-500/10">
                            Cancelled
                          </Badge>
                        ) : (
                          <Badge variant="outline" className="border-slate-500 text-slate-500 bg-slate-500/10">
                            Expired
                          </Badge>
                        )}
                      </td>

                      {/* Actions */}
                      <td className="py-3.5 px-4 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          <Button
                            variant="outline"
                            size="sm"
                            className="h-7 text-xs gap-1"
                            onClick={() => handleOpenInvoice(item.id)}
                            disabled={loadingInvoiceId === item.id}
                          >
                            <FileText className="h-3.5 w-3.5 text-primary" />
                            {loadingInvoiceId === item.id ? 'Loading...' : 'View Invoice'}
                          </Button>

                          <Button
                            variant="ghost"
                            size="icon"
                            className="h-7 w-7 text-muted-foreground hover:text-foreground"
                            title="Print / Save PDF in new tab"
                            onClick={() => handlePrintDirect(item.id)}
                          >
                            <Printer className="h-3.5 w-3.5 text-blue-500" />
                          </Button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* GST Tax Invoice Modal */}
      {selectedInvoice && (
        <GstInvoiceModal
          invoice={selectedInvoice}
          onClose={() => setSelectedInvoice(null)}
        />
      )}
    </div>
  )
}
