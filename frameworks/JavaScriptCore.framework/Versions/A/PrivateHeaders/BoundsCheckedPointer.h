/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer. 
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution. 
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission. 
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef WTF_BoundsCheckedPointer_h
#define WTF_BoundsCheckedPointer_h

#include "Assertions.h"
#include "UnusedParam.h"

namespace WTF {

// Useful for when you'd like to do pointer arithmetic on a buffer, but
// you'd also like to get some ASSERT()'s that prevent you from overflowing.
// This should be performance-neutral in release builds, while providing
// you with strong assertions in debug builds. Note that all of the
// asserting happens when you actually access the pointer. You are allowed
// to overflow or underflow with arithmetic so long as no accesses are
// performed.

template<typename T>
class BoundsCheckedPointer {
public:
    BoundsCheckedPointer()
        : m_pointer(0)
#if !ASSERT_DISABLED
        , m_begin(0)
        , m_end(0)
#endif
    {
    }

    BoundsCheckedPointer(T* pointer, size_t numElements)
        : m_pointer(pointer)
#if !ASSERT_DISABLED
        , m_begin(pointer)
        , m_end(pointer + numElements)
#endif
    {
        UNUSED_PARAM(numElements);
    }
    
    BoundsCheckedPointer(T* pointer, T* end)
        : m_pointer(pointer)
#if !ASSERT_DISABLED
        , m_begin(pointer)
        , m_end(end)
#endif
    {
        UNUSED_PARAM(end);
    }

    BoundsCheckedPointer(T* pointer, T* begin, size_t numElements)
        : m_pointer(pointer)
#if !ASSERT_DISABLED
        , m_begin(begin)
        , m_end(begin + numElements)
#endif
    {
        UNUSED_PARAM(begin);
        UNUSED_PARAM(numElements);
    }
    
    BoundsCheckedPointer(T* pointer, T* begin, T* end)
        : m_pointer(pointer)
#if !ASSERT_DISABLED
        , m_begin(begin)
        , m_end(end)
#endif
    {
        UNUSED_PARAM(begin);
        UNUSED_PARAM(end);
    }
    
    BoundsCheckedPointer& operator=(T* value)
    {
        m_pointer = value;
        return *this;
    }
    
    BoundsCheckedPointer& operator+=(ptrdiff_t amount)
    {
        m_pointer += amount;
        return *this;
    }

    BoundsCheckedPointer& operator-=(ptrdiff_t amount)
    {
        m_pointer -= amount;
        return *this;
    }
    
    BoundsCheckedPointer operator+(ptrdiff_t amount) const
    {
        BoundsCheckedPointer result = *this;
        result.m_pointer += amount;
        return result;
    }

    BoundsCheckedPointer operator-(ptrdiff_t amount) const
    {
        BoundsCheckedPointer result = *this;
        result.m_pointer -= amount;
        return result;
    }
    
    BoundsCheckedPointer operator++() // prefix
    {
        m_pointer++;
        return *this;
    }

    BoundsCheckedPointer operator--() // prefix
    {
        m_pointer--;
        return *this;
    }

    BoundsCheckedPointer operator++(int) // postfix
    {
        BoundsCheckedPointer result = *this;
        m_pointer++;
        return result;
    }

    BoundsCheckedPointer operator--(int) // postfix
    {
        BoundsCheckedPointer result = *this;
        m_pointer--;
        return result;
    }
    
    bool operator<(T* other) const
    {
        return m_pointer < other;
    }

    bool operator<=(T* other) const
    {
        return m_pointer <= other;
    }

    bool operator>(T* other) const
    {
        return m_pointer > other;
    }

    bool operator>=(T* other) const
    {
        return m_pointer >= other;
    }

    bool operator==(T* other) const
    {
        return m_pointer == other;
    }

    bool operator!=(T* other) const
    {
        return m_pointer != other;
    }

    bool operator<(BoundsCheckedPointer other) const
    {
        return m_pointer < other.m_pointer;
    }

    bool operator<=(BoundsCheckedPointer other) const
    {
        return m_pointer <= other.m_pointer;
    }

    bool operator>(BoundsCheckedPointer other) const
    {
        return m_pointer > other.m_pointer;
    }

    bool operator>=(BoundsCheckedPointer other) const
    {
        return m_pointer >= other.m_pointer;
    }

    bool operator==(BoundsCheckedPointer other) const
    {
        return m_pointer == other.m_pointer;
    }

    bool operator!=(BoundsCheckedPointer other) const
    {
        return m_pointer != other.m_pointer;
    }

    BoundsCheckedPointer operator!()
    {
        return !m_pointer;
    }
    
    T* get()
    {
        return m_pointer;
    }
    
    T& operator*()
    {
        validate();
        return *m_pointer;
    }

    const T& operator*() const
    {
        validate();
        return *m_pointer;
    }

    T& operator[](ptrdiff_t index)
    {
        validate(m_pointer + index);
        return m_pointer[index];
    }

    const T& operator[](ptrdiff_t index) const
    {
        validate(m_pointer + index);
        return m_pointer[index];
    }
    
    // The only thing this has in common with strcat() is that it
    // keeps appending from the given pointer until reaching 0.
    BoundsCheckedPointer& strcat(const T* source)
    {
        while (*source)
            *(*this)++ = *source++;
        return *this;
    }

private:
    void validate(T* pointer) const
    {
        ASSERT_UNUSED(pointer, pointer >= m_begin);
        
        // This guard is designed to protect against the misaligned case.
        // A simple pointer < m_end would miss the case if, for example,
        // T = int16_t and pointer is 1 byte less than m_end.
        ASSERT_UNUSED(pointer, pointer + 1 <= m_end);
    }
    
    void validate() const
    {
        validate(m_pointer);
    }
    
    T* m_pointer;
#if !ASSERT_DISABLED
    T* m_begin;
    T* m_end;
#endif
};

} // namespace WTF

using WTF::BoundsCheckedPointer;

#endif // WTF_BoundsCheckedPointer_h
