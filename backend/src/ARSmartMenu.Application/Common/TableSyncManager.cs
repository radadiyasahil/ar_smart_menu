using System.Collections.Concurrent;

namespace ARSmartMenu.Application.Common;

public record TableSyncEvent(
    Guid BusinessId,
    string TableNumber,
    string EventType,
    long TableVersion,
    long BusinessVersion,
    DateTime Timestamp,
    object? Data = null
);

/// <summary>
/// High-performance thread-safe table concurrency coordinator.
/// Enforces serialized one-by-one execution per table and broadcasts real-time sub-second sync events between customer and owner.
/// </summary>
public static class TableSyncManager
{
    private static readonly ConcurrentDictionary<string, SemaphoreSlim> _locks = new(StringComparer.OrdinalIgnoreCase);
    private static readonly ConcurrentDictionary<string, long> _tableVersions = new(StringComparer.OrdinalIgnoreCase);
    private static readonly ConcurrentDictionary<Guid, long> _businessVersions = new();

    private static readonly ConcurrentDictionary<string, List<TaskCompletionSource<TableSyncEvent>>> _tableWaiters = new(StringComparer.OrdinalIgnoreCase);
    private static readonly ConcurrentDictionary<Guid, List<TaskCompletionSource<TableSyncEvent>>> _businessWaiters = new();
    private static readonly object _waiterLock = new();

    public static string NormalizeTableKey(Guid businessId, string tableNumber)
    {
        var clean = tableNumber?.Trim().ToLowerInvariant().Replace("table", "").Trim() ?? "dine-in";
        if (string.IsNullOrEmpty(clean)) clean = "dine-in";
        return $"{businessId:D}:{clean}";
    }

    /// <summary>
    /// Acquires a serialized lock for operations on this specific table.
    /// Guarantees that concurrent requests execute one-by-one with zero race conditions.
    /// </summary>
    public static async Task<IDisposable> AcquireTableLockAsync(Guid businessId, string tableNumber, CancellationToken ct = default)
    {
        var key = NormalizeTableKey(businessId, tableNumber);
        var sem = _locks.GetOrAdd(key, _ => new SemaphoreSlim(1, 1));

        var acquired = await sem.WaitAsync(TimeSpan.FromSeconds(15), ct);
        if (!acquired)
        {
            throw new TimeoutException($"Could not acquire table lock for table '{tableNumber}' within timeout. Another operation is in progress.");
        }

        return new TableLockReleaser(sem);
    }

    public static long GetTableVersion(Guid businessId, string tableNumber)
    {
        var key = NormalizeTableKey(businessId, tableNumber);
        return _tableVersions.TryGetValue(key, out var ver) ? ver : 1;
    }

    public static long GetBusinessVersion(Guid businessId)
    {
        return _businessVersions.TryGetValue(businessId, out var ver) ? ver : 1;
    }

    /// <summary>
    /// Broadcasts an event to notify both owner and customer in real-time.
    /// Increments table & business version and wakes up any awaiting long-poll listeners immediately.
    /// </summary>
    public static void Broadcast(Guid businessId, string tableNumber, string eventType, object? payload = null)
    {
        var key = NormalizeTableKey(businessId, tableNumber);
        var tVer = _tableVersions.AddOrUpdate(key, 2, (_, v) => v + 1);
        var bVer = _businessVersions.AddOrUpdate(businessId, 2, (_, v) => v + 1);

        var evt = new TableSyncEvent(businessId, tableNumber, eventType, tVer, bVer, DateTime.UtcNow, payload);

        List<TaskCompletionSource<TableSyncEvent>>? tableTcsList = null;
        List<TaskCompletionSource<TableSyncEvent>>? bizTcsList = null;

        lock (_waiterLock)
        {
            if (_tableWaiters.TryRemove(key, out var tList))
            {
                tableTcsList = tList;
            }
            if (_businessWaiters.TryRemove(businessId, out var bList))
            {
                bizTcsList = bList;
            }
        }

        if (tableTcsList != null)
        {
            foreach (var tcs in tableTcsList)
            {
                tcs.TrySetResult(evt);
            }
        }

        if (bizTcsList != null)
        {
            foreach (var tcs in bizTcsList)
            {
                tcs.TrySetResult(evt);
            }
        }
    }

    public static async Task<TableSyncEvent?> WaitForTableUpdateAsync(
        Guid businessId, string tableNumber, long lastKnownVersion, TimeSpan timeout, CancellationToken ct)
    {
        var key = NormalizeTableKey(businessId, tableNumber);
        var currentVer = GetTableVersion(businessId, tableNumber);
        var bVer = GetBusinessVersion(businessId);

        if (currentVer > lastKnownVersion)
        {
            return new TableSyncEvent(businessId, tableNumber, "immediate_sync", currentVer, bVer, DateTime.UtcNow);
        }

        var tcs = new TaskCompletionSource<TableSyncEvent>(TaskCreationOptions.RunContinuationsAsynchronously);

        lock (_waiterLock)
        {
            var list = _tableWaiters.GetOrAdd(key, _ => new List<TaskCompletionSource<TableSyncEvent>>());
            list.Add(tcs);
        }

        using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        linkedCts.CancelAfter(timeout);

        using (linkedCts.Token.Register(() => tcs.TrySetCanceled()))
        {
            try
            {
                return await tcs.Task;
            }
            catch (OperationCanceledException)
            {
                return new TableSyncEvent(businessId, tableNumber, "timeout", currentVer, bVer, DateTime.UtcNow);
            }
            finally
            {
                lock (_waiterLock)
                {
                    if (_tableWaiters.TryGetValue(key, out var list))
                    {
                        list.Remove(tcs);
                    }
                }
            }
        }
    }

    public static async Task<TableSyncEvent?> WaitForBusinessUpdateAsync(
        Guid businessId, long lastKnownVersion, TimeSpan timeout, CancellationToken ct)
    {
        var currentVer = GetBusinessVersion(businessId);

        if (currentVer > lastKnownVersion)
        {
            return new TableSyncEvent(businessId, "*", "immediate_sync", 0, currentVer, DateTime.UtcNow);
        }

        var tcs = new TaskCompletionSource<TableSyncEvent>(TaskCreationOptions.RunContinuationsAsynchronously);

        lock (_waiterLock)
        {
            var list = _businessWaiters.GetOrAdd(businessId, _ => new List<TaskCompletionSource<TableSyncEvent>>());
            list.Add(tcs);
        }

        using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        linkedCts.CancelAfter(timeout);

        using (linkedCts.Token.Register(() => tcs.TrySetCanceled()))
        {
            try
            {
                return await tcs.Task;
            }
            catch (OperationCanceledException)
            {
                return new TableSyncEvent(businessId, "*", "timeout", 0, currentVer, DateTime.UtcNow);
            }
            finally
            {
                lock (_waiterLock)
                {
                    if (_businessWaiters.TryGetValue(businessId, out var list))
                    {
                        list.Remove(tcs);
                    }
                }
            }
        }
    }

    private sealed class TableLockReleaser : IDisposable
    {
        private readonly SemaphoreSlim _sem;
        private bool _disposed;

        public TableLockReleaser(SemaphoreSlim sem) => _sem = sem;

        public void Dispose()
        {
            if (!_disposed)
            {
                _disposed = true;
                _sem.Release();
            }
        }
    }
}
