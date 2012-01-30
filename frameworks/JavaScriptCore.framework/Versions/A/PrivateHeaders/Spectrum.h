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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef Spectrum_h
#define Spectrum_h

#include "HashMap.h"
#include "Vector.h"
#include <algorithm>

namespace WTF {

template<typename T>
class Spectrum {
public:
    typedef typename HashMap<T, unsigned long>::iterator iterator;
    typedef typename HashMap<T, unsigned long>::const_iterator const_iterator;
    
    Spectrum() { }
    
    void add(const T& key, unsigned long count = 1)
    {
        std::pair<iterator, bool> result = m_map.add(key, count);
        if (!result.second)
            result.first->second += count;
    }
    
    unsigned long get(const T& key) const
    {
        const_iterator iter = m_map.find(key);
        if (iter == m_map.end())
            return 0;
        return iter->second;
    }
    
    iterator begin() { return m_map.begin(); }
    iterator end() { return m_map.end(); }
    const_iterator begin() const { return m_map.begin(); }
    const_iterator end() const { return m_map.end(); }
    
    struct KeyAndCount {
        KeyAndCount() { }
        
        KeyAndCount(const T& key, unsigned long count)
            : key(key)
            , count(count)
        {
        }
        
        bool operator<(const KeyAndCount& other) const
        {
            if (count != other.count)
                return count < other.count;
            // This causes lower-ordered keys being returned first; this is really just
            // here to make sure that the order is somewhat deterministic rather than being
            // determined by hashing.
            return key > other.key;
        }

        T key;
        unsigned long count;
    };
    
    // Returns a list ordered from lowest-count to highest-count.
    Vector<KeyAndCount> buildList() const
    {
        Vector<KeyAndCount> list;
        for (const_iterator iter = begin(); iter != end(); ++iter)
            list.append(KeyAndCount(iter->first, iter->second));
        
        std::sort(list.begin(), list.end());
        return list;
    }
    
private:
    HashMap<T, unsigned long> m_map;
};

} // namespace WTF

using WTF::Spectrum;

#endif // Spectrum_h
