using System;
using System.Collections.Concurrent;
using System.Collections.ObjectModel;
using PraxisWpf.Interfaces;
using PraxisWpf.Models;

namespace PraxisWpf.Services
{
    /// <summary>
    /// Object pool for frequently allocated objects to reduce GC pressure
    /// </summary>
    public static class ObjectPool
    {
        private static readonly ConcurrentQueue<ObservableCollection<TimeEntry>> _timeEntryCollections = new();
        private static readonly ConcurrentQueue<ObservableCollection<IDisplayableItem>> _displayableItemCollections = new();
        private const int MAX_POOLED_OBJECTS = 20;

        /// <summary>
        /// Get a pooled TimeEntry ObservableCollection or create new one
        /// </summary>
        public static ObservableCollection<TimeEntry> GetTimeEntryCollection()
        {
            if (_timeEntryCollections.TryDequeue(out var collection))
            {
                collection.Clear(); // Ensure it's clean
                Logger.Debug("ObjectPool", "Reused pooled TimeEntry collection");
                return collection;
            }

            Logger.Debug("ObjectPool", "Created new TimeEntry collection");
            return new ObservableCollection<TimeEntry>();
        }

        /// <summary>
        /// Return a TimeEntry ObservableCollection to the pool
        /// </summary>
        public static void ReturnTimeEntryCollection(ObservableCollection<TimeEntry> collection)
        {
            if (collection == null || _timeEntryCollections.Count >= MAX_POOLED_OBJECTS)
                return;

            collection.Clear(); // Clean before returning to pool
            _timeEntryCollections.Enqueue(collection);
            Logger.Debug("ObjectPool", "Returned TimeEntry collection to pool");
        }

        /// <summary>
        /// Get a pooled IDisplayableItem ObservableCollection or create new one
        /// </summary>
        public static ObservableCollection<IDisplayableItem> GetDisplayableItemCollection()
        {
            if (_displayableItemCollections.TryDequeue(out var collection))
            {
                collection.Clear(); // Ensure it's clean
                Logger.Debug("ObjectPool", "Reused pooled IDisplayableItem collection");
                return collection;
            }

            Logger.Debug("ObjectPool", "Created new IDisplayableItem collection");
            return new ObservableCollection<IDisplayableItem>();
        }

        /// <summary>
        /// Return an IDisplayableItem ObservableCollection to the pool
        /// </summary>
        public static void ReturnDisplayableItemCollection(ObservableCollection<IDisplayableItem> collection)
        {
            if (collection == null || _displayableItemCollections.Count >= MAX_POOLED_OBJECTS)
                return;

            collection.Clear(); // Clean before returning to pool
            _displayableItemCollections.Enqueue(collection);
            Logger.Debug("ObjectPool", "Returned IDisplayableItem collection to pool");
        }

        /// <summary>
        /// Clear all pooled objects to free memory
        /// </summary>
        public static void ClearPools()
        {
            var timeEntryCount = _timeEntryCollections.Count;
            var displayableItemCount = _displayableItemCollections.Count;

            while (_timeEntryCollections.TryDequeue(out _)) { }
            while (_displayableItemCollections.TryDequeue(out _)) { }

            Logger.Info("ObjectPool", $"Cleared object pools: {timeEntryCount} TimeEntry collections, {displayableItemCount} IDisplayableItem collections");
        }

        /// <summary>
        /// Get pool statistics for monitoring
        /// </summary>
        public static (int TimeEntryCollections, int DisplayableItemCollections) GetPoolStats()
        {
            return (_timeEntryCollections.Count, _displayableItemCollections.Count);
        }
    }
}