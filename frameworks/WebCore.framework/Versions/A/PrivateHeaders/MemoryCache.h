/*
    Copyright (C) 1998 Lars Knoll (knoll@mpi-hd.mpg.de)
    Copyright (C) 2001 Dirk Mueller <mueller@kde.org>
    Copyright (C) 2004, 2005, 2006, 2007, 2008 Apple Inc. All rights reserved.

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public License
    along with this library; see the file COPYING.LIB.  If not, write to
    the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1301, USA.

    This class provides all functionality needed for loading images, style sheets and html
    pages from the web. It has a memory cache for these objects.
*/

#ifndef Cache_h
#define Cache_h

#include "CachedResource.h"
#include "PlatformString.h"
#include <wtf/HashMap.h>
#include <wtf/HashSet.h>
#include <wtf/Noncopyable.h>
#include <wtf/Vector.h>
#include <wtf/text/StringHash.h>

namespace WebCore  {

class CachedCSSStyleSheet;
class CachedResource;
class CachedResourceLoader;
class KURL;
class SecurityOrigin;
struct SecurityOriginHash;

// This cache holds subresources used by Web pages: images, scripts, stylesheets, etc.

// The cache keeps a flexible but bounded window of dead resources that grows/shrinks 
// depending on the live resource load. Here's an example of cache growth over time,
// with a min dead resource capacity of 25% and a max dead resource capacity of 50%:

//        |-----|                              Dead: -
//        |----------|                         Live: +
//      --|----------|                         Cache boundary: | (objects outside this mark have been evicted)
//      --|----------++++++++++|
// -------|-----+++++++++++++++|
// -------|-----+++++++++++++++|+++++

// The behavior of the cache changes in the following way if shouldMakeResourcePurgeableOnEviction
// returns true.
//
// 1. Dead resources in the cache are kept in non-purgeable memory.
// 2. When we prune dead resources, instead of freeing them, we mark their memory as purgeable and
//    keep the resources until the kernel reclaims the purgeable memory.
//
// By leaving the in-cache dead resources in dirty resident memory, we decrease the likelihood of
// the kernel claiming that memory and forcing us to refetch the resource (for example when a user
// presses back).
//
// And by having an unbounded number of resource objects using purgeable memory, we can use as much
// memory as is available on the machine. The trade-off here is that the CachedResource object (and
// its member variables) are allocated in non-purgeable TC-malloc'd memory so we would see slightly
// more memory use due to this.

class MemoryCache {
    WTF_MAKE_NONCOPYABLE(MemoryCache); WTF_MAKE_FAST_ALLOCATED;
public:
    friend MemoryCache* memoryCache();

    typedef HashMap<String, CachedResource*> CachedResourceMap;

    struct LRUList {
        CachedResource* m_head;
        CachedResource* m_tail;
        LRUList() : m_head(0), m_tail(0) { }
    };

    struct TypeStatistic {
        int count;
        int size;
        int liveSize;
        int decodedSize;
        int purgeableSize;
        int purgedSize;
        TypeStatistic() : count(0), size(0), liveSize(0), decodedSize(0), purgeableSize(0), purgedSize(0) { }
        void addResource(CachedResource*);
    };
    
    struct Statistics {
        TypeStatistic images;
        TypeStatistic cssStyleSheets;
        TypeStatistic scripts;
        TypeStatistic xslStyleSheets;
        TypeStatistic fonts;
    };
    
    CachedResource* resourceForURL(const KURL&);
    
    bool add(CachedResource* resource);
    void remove(CachedResource* resource) { evict(resource); }

    static KURL removeFragmentIdentifierIfNeeded(const KURL& originalURL);
    
    void revalidationSucceeded(CachedResource* revalidatingResource, const ResourceResponse&);
    void revalidationFailed(CachedResource* revalidatingResource);
    
    // Sets the cache's memory capacities, in bytes. These will hold only approximately, 
    // since the decoded cost of resources like scripts and stylesheets is not known.
    //  - minDeadBytes: The maximum number of bytes that dead resources should consume when the cache is under pressure.
    //  - maxDeadBytes: The maximum number of bytes that dead resources should consume when the cache is not under pressure.
    //  - totalBytes: The maximum number of bytes that the cache should consume overall.
    void setCapacities(unsigned minDeadBytes, unsigned maxDeadBytes, unsigned totalBytes);

    // Turn the cache on and off.  Disabling the cache will remove all resources from the cache.  They may
    // still live on if they are referenced by some Web page though.
    void setDisabled(bool);
    bool disabled() const { return m_disabled; }

    void evictResources();
    
    void setPruneEnabled(bool enabled) { m_pruneEnabled = enabled; }
    void prune();
    void pruneToPercentage(float targetPercentLive);

    void setDeadDecodedDataDeletionInterval(double interval) { m_deadDecodedDataDeletionInterval = interval; }
    double deadDecodedDataDeletionInterval() const { return m_deadDecodedDataDeletionInterval; }

    void addCachedResourceLoader(CachedResourceLoader*);
    void removeCachedResourceLoader(CachedResourceLoader*);

    // Calls to put the cached resource into and out of LRU lists.
    void insertInLRUList(CachedResource*);
    void removeFromLRUList(CachedResource*);

    // Called to adjust the cache totals when a resource changes size.
    void adjustSize(bool live, int delta);

    // Track decoded resources that are in the cache and referenced by a Web page.
    void insertInLiveDecodedResourcesList(CachedResource*);
    void removeFromLiveDecodedResourcesList(CachedResource*);

    void addToLiveResourcesSize(CachedResource*);
    void removeFromLiveResourcesSize(CachedResource*);

    static bool shouldMakeResourcePurgeableOnEviction();

    // Function to collect cache statistics for the caches window in the Safari Debug menu.
    Statistics getStatistics();
    
    void resourceAccessed(CachedResource*);

    typedef HashSet<RefPtr<SecurityOrigin>, SecurityOriginHash> SecurityOriginSet;
    void removeResourcesWithOrigin(SecurityOrigin*);
    void getOriginsWithCache(SecurityOriginSet& origins);

private:
    MemoryCache();
    ~MemoryCache(); // Not implemented to make sure nobody accidentally calls delete -- WebCore does not delete singletons.
       
    LRUList* lruListFor(CachedResource*);
#ifndef NDEBUG
    void dumpStats();
    void dumpLRULists(bool includeLive) const;
#endif

    unsigned liveCapacity() const;
    unsigned deadCapacity() const;

    // pruneDead*() - Flush decoded and encoded data from resources not referenced by Web pages.
    // pruneLive*() - Flush decoded data from resources still referenced by Web pages.
    void pruneDeadResources(); // Automatically decide how much to prune.
    void pruneLiveResources();
    void pruneDeadResourcesToPercentage(float prunePercentage); // Prune to % current size
    void pruneLiveResourcesToPercentage(float prunePercentage);
    void pruneDeadResourcesToSize(unsigned targetSize);
    void pruneLiveResourcesToSize(unsigned targetSize);

    bool makeResourcePurgeable(CachedResource*);
    void evict(CachedResource*);

    bool m_disabled;  // Whether or not the cache is enabled.
    bool m_pruneEnabled;
    bool m_inPruneDeadResources;

    unsigned m_capacity;
    unsigned m_minDeadCapacity;
    unsigned m_maxDeadCapacity;
    double m_deadDecodedDataDeletionInterval;

    unsigned m_liveSize; // The number of bytes currently consumed by "live" resources in the cache.
    unsigned m_deadSize; // The number of bytes currently consumed by "dead" resources in the cache.

    // Size-adjusted and popularity-aware LRU list collection for cache objects.  This collection can hold
    // more resources than the cached resource map, since it can also hold "stale" multiple versions of objects that are
    // waiting to die when the clients referencing them go away.
    Vector<LRUList, 32> m_allResources;
    
    // List just for live resources with decoded data.  Access to this list is based off of painting the resource.
    LRUList m_liveDecodedResources;
    
    // A URL-based map of all resources that are in the cache (including the freshest version of objects that are currently being 
    // referenced by a Web page).
    HashMap<String, CachedResource*> m_resources;
};

inline bool MemoryCache::shouldMakeResourcePurgeableOnEviction()
{
#if PLATFORM(IOS)
    return true;
#else
    return false;
#endif
}

// Function to obtain the global cache.
MemoryCache* memoryCache();

}

#endif
