/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef MarkedBlockSet_h
#define MarkedBlockSet_h

#include "MarkedBlock.h"
#include "TinyBloomFilter.h"
#include <wtf/HashSet.h>

namespace JSC {

class MarkedBlock;

class MarkedBlockSet {
public:
    void add(MarkedBlock*);
    void remove(MarkedBlock*);

    TinyBloomFilter filter() const;
    const HashSet<MarkedBlock*>& set() const;

private:
    void recomputeFilter();

    TinyBloomFilter m_filter;
    HashSet<MarkedBlock*> m_set;
};

inline void MarkedBlockSet::add(MarkedBlock* block)
{
    m_filter.add(reinterpret_cast<Bits>(block));
    m_set.add(block);
}

inline void MarkedBlockSet::remove(MarkedBlock* block)
{
    int oldCapacity = m_set.capacity();
    m_set.remove(block);
    if (m_set.capacity() != oldCapacity) // Indicates we've removed a lot of blocks.
        recomputeFilter();
}

inline void MarkedBlockSet::recomputeFilter()
{
    TinyBloomFilter filter;
    for (HashSet<MarkedBlock*>::iterator it = m_set.begin(); it != m_set.end(); ++it)
        filter.add(reinterpret_cast<Bits>(*it));
    m_filter = filter;
}

inline TinyBloomFilter MarkedBlockSet::filter() const
{
    return m_filter;
}

inline const HashSet<MarkedBlock*>& MarkedBlockSet::set() const
{
    return m_set;
}

} // namespace JSC

#endif // MarkedBlockSet_h
