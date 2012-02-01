/*
 * Copyright (C) 2007, 2008 Apple Inc. All rights reserved.
 * Copyright (C) 2009 Google Inc. All rights reserved.
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

#ifndef WTF_Deque_h
#define WTF_Deque_h

// FIXME: Could move what Vector and Deque share into a separate file.
// Deque doesn't actually use Vector.

#include "PassTraits.h"
#include "Vector.h"

namespace WTF {

    template<typename T, size_t inlineCapacity> class DequeIteratorBase;
    template<typename T, size_t inlineCapacity> class DequeIterator;
    template<typename T, size_t inlineCapacity> class DequeConstIterator;
    template<typename T, size_t inlineCapacity> class DequeReverseIterator;
    template<typename T, size_t inlineCapacity> class DequeConstReverseIterator;

    template<typename T, size_t inlineCapacity = 0>
    class Deque {
        WTF_MAKE_FAST_ALLOCATED;
    public:
        typedef DequeIterator<T, inlineCapacity> iterator;
        typedef DequeConstIterator<T, inlineCapacity> const_iterator;
        typedef DequeReverseIterator<T, inlineCapacity> reverse_iterator;
        typedef DequeConstReverseIterator<T, inlineCapacity> const_reverse_iterator;
        typedef PassTraits<T> Pass;
        typedef typename PassTraits<T>::PassType PassType;

        Deque();
        Deque(const Deque<T, inlineCapacity>&);
        Deque& operator=(const Deque<T, inlineCapacity>&);
        ~Deque();

        void swap(Deque<T, inlineCapacity>&);

        size_t size() const { return m_start <= m_end ? m_end - m_start : m_end + m_buffer.capacity() - m_start; }
        bool isEmpty() const { return m_start == m_end; }

        iterator begin() { return iterator(this, m_start); }
        iterator end() { return iterator(this, m_end); }
        const_iterator begin() const { return const_iterator(this, m_start); }
        const_iterator end() const { return const_iterator(this, m_end); }
        reverse_iterator rbegin() { return reverse_iterator(this, m_end); }
        reverse_iterator rend() { return reverse_iterator(this, m_start); }
        const_reverse_iterator rbegin() const { return const_reverse_iterator(this, m_end); }
        const_reverse_iterator rend() const { return const_reverse_iterator(this, m_start); }

        T& first() { ASSERT(m_start != m_end); return m_buffer.buffer()[m_start]; }
        const T& first() const { ASSERT(m_start != m_end); return m_buffer.buffer()[m_start]; }
        PassType takeFirst();

        T& last() { ASSERT(m_start != m_end); return *(--end()); }
        const T& last() const { ASSERT(m_start != m_end); return *(--end()); }

        template<typename U> void append(const U&);
        template<typename U> void prepend(const U&);
        void removeFirst();
        void remove(iterator&);
        void remove(const_iterator&);

        void clear();

        template<typename Predicate>
        iterator findIf(Predicate&);

    private:
        friend class DequeIteratorBase<T, inlineCapacity>;

        typedef VectorBuffer<T, inlineCapacity> Buffer;
        typedef VectorTypeOperations<T> TypeOperations;
        typedef DequeIteratorBase<T, inlineCapacity> IteratorBase;

        void remove(size_t position);
        void invalidateIterators();
        void destroyAll();
        void checkValidity() const;
        void checkIndexValidity(size_t) const;
        void expandCapacityIfNeeded();
        void expandCapacity();

        size_t m_start;
        size_t m_end;
        Buffer m_buffer;
#ifndef NDEBUG
        mutable IteratorBase* m_iterators;
#endif
    };

    template<typename T, size_t inlineCapacity = 0>
    class DequeIteratorBase {
    private:
        typedef DequeIteratorBase<T, inlineCapacity> Base;

    protected:
        DequeIteratorBase();
        DequeIteratorBase(const Deque<T, inlineCapacity>*, size_t);
        DequeIteratorBase(const Base&);
        Base& operator=(const Base&);
        ~DequeIteratorBase();

        void assign(const Base& other) { *this = other; }

        void increment();
        void decrement();

        T* before() const;
        T* after() const;

        bool isEqual(const Base&) const;

    private:
        void addToIteratorsList();
        void removeFromIteratorsList();
        void checkValidity() const;
        void checkValidity(const Base&) const;

        Deque<T, inlineCapacity>* m_deque;
        size_t m_index;

        friend class Deque<T, inlineCapacity>;

#ifndef NDEBUG
        mutable DequeIteratorBase* m_next;
        mutable DequeIteratorBase* m_previous;
#endif
    };

    template<typename T, size_t inlineCapacity = 0>
    class DequeIterator : public DequeIteratorBase<T, inlineCapacity> {
    private:
        typedef DequeIteratorBase<T, inlineCapacity> Base;
        typedef DequeIterator<T, inlineCapacity> Iterator;

    public:
        DequeIterator(Deque<T, inlineCapacity>* deque, size_t index) : Base(deque, index) { }

        DequeIterator(const Iterator& other) : Base(other) { }
        DequeIterator& operator=(const Iterator& other) { Base::assign(other); return *this; }

        T& operator*() const { return *Base::after(); }
        T* operator->() const { return Base::after(); }

        bool operator==(const Iterator& other) const { return Base::isEqual(other); }
        bool operator!=(const Iterator& other) const { return !Base::isEqual(other); }

        Iterator& operator++() { Base::increment(); return *this; }
        // postfix ++ intentionally omitted
        Iterator& operator--() { Base::decrement(); return *this; }
        // postfix -- intentionally omitted
    };

    template<typename T, size_t inlineCapacity = 0>
    class DequeConstIterator : public DequeIteratorBase<T, inlineCapacity> {
    private:
        typedef DequeIteratorBase<T, inlineCapacity> Base;
        typedef DequeConstIterator<T, inlineCapacity> Iterator;
        typedef DequeIterator<T, inlineCapacity> NonConstIterator;

    public:
        DequeConstIterator(const Deque<T, inlineCapacity>* deque, size_t index) : Base(deque, index) { }

        DequeConstIterator(const Iterator& other) : Base(other) { }
        DequeConstIterator(const NonConstIterator& other) : Base(other) { }
        DequeConstIterator& operator=(const Iterator& other) { Base::assign(other); return *this; }
        DequeConstIterator& operator=(const NonConstIterator& other) { Base::assign(other); return *this; }

        const T& operator*() const { return *Base::after(); }
        const T* operator->() const { return Base::after(); }

        bool operator==(const Iterator& other) const { return Base::isEqual(other); }
        bool operator!=(const Iterator& other) const { return !Base::isEqual(other); }

        Iterator& operator++() { Base::increment(); return *this; }
        // postfix ++ intentionally omitted
        Iterator& operator--() { Base::decrement(); return *this; }
        // postfix -- intentionally omitted
    };

    template<typename T, size_t inlineCapacity = 0>
    class DequeReverseIterator : public DequeIteratorBase<T, inlineCapacity> {
    private:
        typedef DequeIteratorBase<T, inlineCapacity> Base;
        typedef DequeReverseIterator<T, inlineCapacity> Iterator;

    public:
        DequeReverseIterator(const Deque<T, inlineCapacity>* deque, size_t index) : Base(deque, index) { }

        DequeReverseIterator(const Iterator& other) : Base(other) { }
        DequeReverseIterator& operator=(const Iterator& other) { Base::assign(other); return *this; }

        T& operator*() const { return *Base::before(); }
        T* operator->() const { return Base::before(); }

        bool operator==(const Iterator& other) const { return Base::isEqual(other); }
        bool operator!=(const Iterator& other) const { return !Base::isEqual(other); }

        Iterator& operator++() { Base::decrement(); return *this; }
        // postfix ++ intentionally omitted
        Iterator& operator--() { Base::increment(); return *this; }
        // postfix -- intentionally omitted
    };

    template<typename T, size_t inlineCapacity = 0>
    class DequeConstReverseIterator : public DequeIteratorBase<T, inlineCapacity> {
    private:
        typedef DequeIteratorBase<T, inlineCapacity> Base;
        typedef DequeConstReverseIterator<T, inlineCapacity> Iterator;
        typedef DequeReverseIterator<T, inlineCapacity> NonConstIterator;

    public:
        DequeConstReverseIterator(const Deque<T, inlineCapacity>* deque, size_t index) : Base(deque, index) { }

        DequeConstReverseIterator(const Iterator& other) : Base(other) { }
        DequeConstReverseIterator(const NonConstIterator& other) : Base(other) { }
        DequeConstReverseIterator& operator=(const Iterator& other) { Base::assign(other); return *this; }
        DequeConstReverseIterator& operator=(const NonConstIterator& other) { Base::assign(other); return *this; }

        const T& operator*() const { return *Base::before(); }
        const T* operator->() const { return Base::before(); }

        bool operator==(const Iterator& other) const { return Base::isEqual(other); }
        bool operator!=(const Iterator& other) const { return !Base::isEqual(other); }

        Iterator& operator++() { Base::decrement(); return *this; }
        // postfix ++ intentionally omitted
        Iterator& operator--() { Base::increment(); return *this; }
        // postfix -- intentionally omitted
    };

#ifdef NDEBUG
    template<typename T, size_t inlineCapacity> inline void Deque<T, inlineCapacity>::checkValidity() const { }
    template<typename T, size_t inlineCapacity> inline void Deque<T, inlineCapacity>::checkIndexValidity(size_t) const { }
    template<typename T, size_t inlineCapacity> inline void Deque<T, inlineCapacity>::invalidateIterators() { }
#else
    template<typename T, size_t inlineCapacity>
    void Deque<T, inlineCapacity>::checkValidity() const
    {
        // In this implementation a capacity of 1 would confuse append() and
        // other places that assume the index after capacity - 1 is 0.
        ASSERT(m_buffer.capacity() != 1);

        if (!m_buffer.capacity()) {
            ASSERT(!m_start);
            ASSERT(!m_end);
        } else {
            ASSERT(m_start < m_buffer.capacity());
            ASSERT(m_end < m_buffer.capacity());
        }
    }

    template<typename T, size_t inlineCapacity>
    void Deque<T, inlineCapacity>::checkIndexValidity(size_t index) const
    {
        ASSERT_UNUSED(index, index <= m_buffer.capacity());
        if (m_start <= m_end) {
            ASSERT(index >= m_start);
            ASSERT(index <= m_end);
        } else {
            ASSERT(index >= m_start || index <= m_end);
        }
    }

    template<typename T, size_t inlineCapacity>
    void Deque<T, inlineCapacity>::invalidateIterators()
    {
        IteratorBase* next;
        for (IteratorBase* p = m_iterators; p; p = next) {
            next = p->m_next;
            p->m_deque = 0;
            p->m_next = 0;
            p->m_previous = 0;
        }
        m_iterators = 0;
    }
#endif

    template<typename T, size_t inlineCapacity>
    inline Deque<T, inlineCapacity>::Deque()
        : m_start(0)
        , m_end(0)
#ifndef NDEBUG
        , m_iterators(0)
#endif
    {
        checkValidity();
    }

    template<typename T, size_t inlineCapacity>
    inline Deque<T, inlineCapacity>::Deque(const Deque<T, inlineCapacity>& other)
        : m_start(other.m_start)
        , m_end(other.m_end)
        , m_buffer(other.m_buffer.capacity())
#ifndef NDEBUG
        , m_iterators(0)
#endif
    {
        const T* otherBuffer = other.m_buffer.buffer();
        if (m_start <= m_end)
            TypeOperations::uninitializedCopy(otherBuffer + m_start, otherBuffer + m_end, m_buffer.buffer() + m_start);
        else {
            TypeOperations::uninitializedCopy(otherBuffer, otherBuffer + m_end, m_buffer.buffer());
            TypeOperations::uninitializedCopy(otherBuffer + m_start, otherBuffer + m_buffer.capacity(), m_buffer.buffer() + m_start);
        }
    }

    template<typename T, size_t inlineCapacity>
    void deleteAllValues(const Deque<T, inlineCapacity>& collection)
    {
        typedef typename Deque<T, inlineCapacity>::const_iterator iterator;
        iterator end = collection.end();
        for (iterator it = collection.begin(); it != end; ++it)
            delete *it;
    }

    template<typename T, size_t inlineCapacity>
    inline Deque<T, inlineCapacity>& Deque<T, inlineCapacity>::operator=(const Deque<T, inlineCapacity>& other)
    {
        // FIXME: This is inefficient if we're using an inline buffer and T is
        // expensive to copy since it will copy the buffer twice instead of once.
        Deque<T> copy(other);
        swap(copy);
        return *this;
    }

    template<typename T, size_t inlineCapacity>
    inline void Deque<T, inlineCapacity>::destroyAll()
    {
        if (m_start <= m_end)
            TypeOperations::destruct(m_buffer.buffer() + m_start, m_buffer.buffer() + m_end);
        else {
            TypeOperations::destruct(m_buffer.buffer(), m_buffer.buffer() + m_end);
            TypeOperations::destruct(m_buffer.buffer() + m_start, m_buffer.buffer() + m_buffer.capacity());
        }
    }

    template<typename T, size_t inlineCapacity>
    inline Deque<T, inlineCapacity>::~Deque()
    {
        checkValidity();
        invalidateIterators();
        destroyAll();
    }

    template<typename T, size_t inlineCapacity>
    inline void Deque<T, inlineCapacity>::swap(Deque<T, inlineCapacity>& other)
    {
        checkValidity();
        other.checkValidity();
        invalidateIterators();
        std::swap(m_start, other.m_start);
        std::swap(m_end, other.m_end);
        m_buffer.swap(other.m_buffer);
        checkValidity();
        other.checkValidity();
    }

    template<typename T, size_t inlineCapacity>
    inline void Deque<T, inlineCapacity>::clear()
    {
        checkValidity();
        invalidateIterators();
        destroyAll();
        m_start = 0;
        m_end = 0;
        checkValidity();
    }

    template<typename T, size_t inlineCapacity>
    template<typename Predicate>
    inline DequeIterator<T, inlineCapacity> Deque<T, inlineCapacity>::findIf(Predicate& predicate)
    {
        iterator end_iterator = end();
        for (iterator it = begin(); it != end_iterator; ++it) {
            if (predicate(*it))
                return it;
        }
        return end_iterator;
    }

    template<typename T, size_t inlineCapacity>
    inline void Deque<T, inlineCapacity>::expandCapacityIfNeeded()
    {
        if (m_start) {
            if (m_end + 1 != m_start)
                return;
        } else if (m_end) {
            if (m_end != m_buffer.capacity() - 1)
                return;
        } else if (m_buffer.capacity())
            return;

        expandCapacity();
    }

    template<typename T, size_t inlineCapacity>
    void Deque<T, inlineCapacity>::expandCapacity()
    {
        checkValidity();
        size_t oldCapacity = m_buffer.capacity();
        size_t newCapacity = max(static_cast<size_t>(16), oldCapacity + oldCapacity / 4 + 1);
        T* oldBuffer = m_buffer.buffer();
        m_buffer.allocateBuffer(newCapacity);
        if (m_start <= m_end)
            TypeOperations::move(oldBuffer + m_start, oldBuffer + m_end, m_buffer.buffer() + m_start);
        else {
            TypeOperations::move(oldBuffer, oldBuffer + m_end, m_buffer.buffer());
            size_t newStart = newCapacity - (oldCapacity - m_start);
            TypeOperations::move(oldBuffer + m_start, oldBuffer + oldCapacity, m_buffer.buffer() + newStart);
            m_start = newStart;
        }
        m_buffer.deallocateBuffer(oldBuffer);
        checkValidity();
    }

    template<typename T, size_t inlineCapacity>
    inline typename Deque<T, inlineCapacity>::PassType Deque<T, inlineCapacity>::takeFirst()
    {
        T oldFirst = Pass::transfer(first());
        removeFirst();
        return Pass::transfer(oldFirst);
    }

    template<typename T, size_t inlineCapacity> template<typename U>
    inline void Deque<T, inlineCapacity>::append(const U& value)
    {
        checkValidity();
        expandCapacityIfNeeded();
        new (NotNull, &m_buffer.buffer()[m_end]) T(value);
        if (m_end == m_buffer.capacity() - 1)
            m_end = 0;
        else
            ++m_end;
        checkValidity();
    }

    template<typename T, size_t inlineCapacity> template<typename U>
    inline void Deque<T, inlineCapacity>::prepend(const U& value)
    {
        checkValidity();
        expandCapacityIfNeeded();
        if (!m_start)
            m_start = m_buffer.capacity() - 1;
        else
            --m_start;
        new (NotNull, &m_buffer.buffer()[m_start]) T(value);
        checkValidity();
    }

    template<typename T, size_t inlineCapacity>
    inline void Deque<T, inlineCapacity>::removeFirst()
    {
        checkValidity();
        invalidateIterators();
        ASSERT(!isEmpty());
        TypeOperations::destruct(&m_buffer.buffer()[m_start], &m_buffer.buffer()[m_start + 1]);
        if (m_start == m_buffer.capacity() - 1)
            m_start = 0;
        else
            ++m_start;
        checkValidity();
    }

    template<typename T, size_t inlineCapacity>
    inline void Deque<T, inlineCapacity>::remove(iterator& it)
    {
        it.checkValidity();
        remove(it.m_index);
    }

    template<typename T, size_t inlineCapacity>
    inline void Deque<T, inlineCapacity>::remove(const_iterator& it)
    {
        it.checkValidity();
        remove(it.m_index);
    }

    template<typename T, size_t inlineCapacity>
    inline void Deque<T, inlineCapacity>::remove(size_t position)
    {
        if (position == m_end)
            return;

        checkValidity();
        invalidateIterators();

        T* buffer = m_buffer.buffer();
        TypeOperations::destruct(&buffer[position], &buffer[position + 1]);

        // Find which segment of the circular buffer contained the remove element, and only move elements in that part.
        if (position >= m_start) {
            TypeOperations::moveOverlapping(buffer + m_start, buffer + position, buffer + m_start + 1);
            m_start = (m_start + 1) % m_buffer.capacity();
        } else {
            TypeOperations::moveOverlapping(buffer + position + 1, buffer + m_end, buffer + position);
            m_end = (m_end - 1 + m_buffer.capacity()) % m_buffer.capacity();
        }
        checkValidity();
    }

#ifdef NDEBUG
    template<typename T, size_t inlineCapacity> inline void DequeIteratorBase<T, inlineCapacity>::checkValidity() const { }
    template<typename T, size_t inlineCapacity> inline void DequeIteratorBase<T, inlineCapacity>::checkValidity(const DequeIteratorBase<T, inlineCapacity>&) const { }
    template<typename T, size_t inlineCapacity> inline void DequeIteratorBase<T, inlineCapacity>::addToIteratorsList() { }
    template<typename T, size_t inlineCapacity> inline void DequeIteratorBase<T, inlineCapacity>::removeFromIteratorsList() { }
#else
    template<typename T, size_t inlineCapacity>
    void DequeIteratorBase<T, inlineCapacity>::checkValidity() const
    {
        ASSERT(m_deque);
        m_deque->checkIndexValidity(m_index);
    }

    template<typename T, size_t inlineCapacity>
    void DequeIteratorBase<T, inlineCapacity>::checkValidity(const Base& other) const
    {
        checkValidity();
        other.checkValidity();
        ASSERT(m_deque == other.m_deque);
    }

    template<typename T, size_t inlineCapacity>
    void DequeIteratorBase<T, inlineCapacity>::addToIteratorsList()
    {
        if (!m_deque)
            m_next = 0;
        else {
            m_next = m_deque->m_iterators;
            m_deque->m_iterators = this;
            if (m_next)
                m_next->m_previous = this;
        }
        m_previous = 0;
    }

    template<typename T, size_t inlineCapacity>
    void DequeIteratorBase<T, inlineCapacity>::removeFromIteratorsList()
    {
        if (!m_deque) {
            ASSERT(!m_next);
            ASSERT(!m_previous);
        } else {
            if (m_next) {
                ASSERT(m_next->m_previous == this);
                m_next->m_previous = m_previous;
            }
            if (m_previous) {
                ASSERT(m_deque->m_iterators != this);
                ASSERT(m_previous->m_next == this);
                m_previous->m_next = m_next;
            } else {
                ASSERT(m_deque->m_iterators == this);
                m_deque->m_iterators = m_next;
            }
        }
        m_next = 0;
        m_previous = 0;
    }
#endif

    template<typename T, size_t inlineCapacity>
    inline DequeIteratorBase<T, inlineCapacity>::DequeIteratorBase()
        : m_deque(0)
    {
    }

    template<typename T, size_t inlineCapacity>
    inline DequeIteratorBase<T, inlineCapacity>::DequeIteratorBase(const Deque<T, inlineCapacity>* deque, size_t index)
        : m_deque(const_cast<Deque<T, inlineCapacity>*>(deque))
        , m_index(index)
    {
        addToIteratorsList();
        checkValidity();
    }

    template<typename T, size_t inlineCapacity>
    inline DequeIteratorBase<T, inlineCapacity>::DequeIteratorBase(const Base& other)
        : m_deque(other.m_deque)
        , m_index(other.m_index)
    {
        addToIteratorsList();
        checkValidity();
    }

    template<typename T, size_t inlineCapacity>
    inline DequeIteratorBase<T, inlineCapacity>& DequeIteratorBase<T, inlineCapacity>::operator=(const Base& other)
    {
        other.checkValidity();
        removeFromIteratorsList();

        m_deque = other.m_deque;
        m_index = other.m_index;
        addToIteratorsList();
        checkValidity();
        return *this;
    }

    template<typename T, size_t inlineCapacity>
    inline DequeIteratorBase<T, inlineCapacity>::~DequeIteratorBase()
    {
#ifndef NDEBUG
        removeFromIteratorsList();
        m_deque = 0;
#endif
    }

    template<typename T, size_t inlineCapacity>
    inline bool DequeIteratorBase<T, inlineCapacity>::isEqual(const Base& other) const
    {
        checkValidity(other);
        return m_index == other.m_index;
    }

    template<typename T, size_t inlineCapacity>
    inline void DequeIteratorBase<T, inlineCapacity>::increment()
    {
        checkValidity();
        ASSERT(m_index != m_deque->m_end);
        ASSERT(m_deque->m_buffer.capacity());
        if (m_index == m_deque->m_buffer.capacity() - 1)
            m_index = 0;
        else
            ++m_index;
        checkValidity();
    }

    template<typename T, size_t inlineCapacity>
    inline void DequeIteratorBase<T, inlineCapacity>::decrement()
    {
        checkValidity();
        ASSERT(m_index != m_deque->m_start);
        ASSERT(m_deque->m_buffer.capacity());
        if (!m_index)
            m_index = m_deque->m_buffer.capacity() - 1;
        else
            --m_index;
        checkValidity();
    }

    template<typename T, size_t inlineCapacity>
    inline T* DequeIteratorBase<T, inlineCapacity>::after() const
    {
        checkValidity();
        ASSERT(m_index != m_deque->m_end);
        return &m_deque->m_buffer.buffer()[m_index];
    }

    template<typename T, size_t inlineCapacity>
    inline T* DequeIteratorBase<T, inlineCapacity>::before() const
    {
        checkValidity();
        ASSERT(m_index != m_deque->m_start);
        if (!m_index)
            return &m_deque->m_buffer.buffer()[m_deque->m_buffer.capacity() - 1];
        return &m_deque->m_buffer.buffer()[m_index - 1];
    }

} // namespace WTF

using WTF::Deque;

#endif // WTF_Deque_h
