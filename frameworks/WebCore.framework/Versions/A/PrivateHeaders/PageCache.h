/*
 * Copyright (C) 2007 Apple Inc.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef PageCache_h
#define PageCache_h

#include "Timer.h"
#include <wtf/Forward.h>
#include <wtf/HashSet.h>
#include <wtf/Noncopyable.h>

namespace WebCore {

    class CachedPage;
    class Frame;
    class HistoryItem;
    class Page;
    
    class PageCache {
        WTF_MAKE_NONCOPYABLE(PageCache); WTF_MAKE_FAST_ALLOCATED;
    public:
        friend PageCache* pageCache();
        
        static bool canCache(Page*);

        void setCapacity(int); // number of pages to cache
        int capacity() { return m_capacity; }
        
        void add(PassRefPtr<HistoryItem>, Page*); // Prunes if capacity() is exceeded.
        void remove(HistoryItem*);
        CachedPage* get(HistoryItem* item);

        void releaseAutoreleasedPagesNow();
        
        int pageCount() const { return m_size; }
        int frameCount() const;
        int autoreleasedPageCount() const;

        void markPagesForVistedLinkStyleRecalc();

#if USE(ACCELERATED_COMPOSITING)
        bool shouldClearBackingStores() const { return m_shouldClearBackingStores; }
        void setShouldClearBackingStores(bool flag) { m_shouldClearBackingStores = flag; }
#endif

    private:
        typedef HashSet<RefPtr<CachedPage> > CachedPageSet;

        PageCache(); // Use pageCache() instead.
        ~PageCache(); // Not implemented to make sure nobody accidentally calls delete -- WebCore does not delete singletons.
        
        static bool canCachePageContainingThisFrame(Frame*);

        void addToLRUList(HistoryItem*); // Adds to the head of the list.
        void removeFromLRUList(HistoryItem*);

        void prune();

        void autorelease(PassRefPtr<CachedPage>);
        void releaseAutoreleasedPagesNowOrReschedule(Timer<PageCache>*);

        int m_capacity;
        int m_size;

        // LRU List
        HistoryItem* m_head;
        HistoryItem* m_tail;
        
        Timer<PageCache> m_autoreleaseTimer;
        CachedPageSet m_autoreleaseSet;

#if USE(ACCELERATED_COMPOSITING)
        bool m_shouldClearBackingStores;
#endif
     };

    // Function to obtain the global page cache.
    PageCache* pageCache();

} // namespace WebCore

#endif // PageCache_h
