/*
 *  Copyright (C) 1999-2001 Harri Porten (porten@kde.org)
 *  Copyright (C) 2003, 2007, 2008, 2009 Apple Inc. All rights reserved.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public License
 *  along with this library; see the file COPYING.LIB.  If not, write to
 *  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 *  Boston, MA 02110-1301, USA.
 *
 */

#ifndef ArgList_h
#define ArgList_h

#include "CallFrame.h"
#include "Register.h"
#include "WriteBarrier.h"
#include <wtf/HashSet.h>
#include <wtf/Vector.h>

namespace JSC {

    class SlotVisitor;

    class MarkedArgumentBuffer {
        WTF_MAKE_NONCOPYABLE(MarkedArgumentBuffer);
        friend class JSGlobalData;
        friend class ArgList;

    private:
        static const size_t inlineCapacity = 8;
        typedef Vector<Register, inlineCapacity> VectorType;
        typedef HashSet<MarkedArgumentBuffer*> ListSet;

    public:
        // Constructor for a read-write list, to which you may append values.
        // FIXME: Remove all clients of this API, then remove this API.
        MarkedArgumentBuffer()
            : m_size(0)
            , m_capacity(inlineCapacity)
            , m_buffer(&m_inlineBuffer[m_capacity - 1])
            , m_markSet(0)
        {
        }

        ~MarkedArgumentBuffer()
        {
            if (m_markSet)
                m_markSet->remove(this);

            if (EncodedJSValue* base = mallocBase())
                delete [] base;
        }

        size_t size() const { return m_size; }
        bool isEmpty() const { return !m_size; }

        JSValue at(int i) const
        {
            if (i >= m_size)
                return jsUndefined();

            return JSValue::decode(slotFor(i));
        }

        void clear()
        {
            m_size = 0;
        }

        void append(JSValue v)
        {
            if (m_size >= m_capacity)
                return slowAppend(v);

            slotFor(m_size) = JSValue::encode(v);
            ++m_size;
        }

        void removeLast()
        { 
            ASSERT(m_size);
            m_size--;
        }

        JSValue last() 
        {
            ASSERT(m_size);
            return JSValue::decode(slotFor(m_size - 1));
        }
        
        static void markLists(HeapRootVisitor&, ListSet&);

    private:
        JS_EXPORT_PRIVATE void slowAppend(JSValue);
        
        EncodedJSValue& slotFor(int item) const
        {
            return m_buffer[-item];
        }
        
        EncodedJSValue* mallocBase()
        {
            if (m_capacity == static_cast<int>(inlineCapacity))
                return 0;
            return &slotFor(m_capacity - 1);
        }
        
        int m_size;
        int m_capacity;
        EncodedJSValue m_inlineBuffer[inlineCapacity];
        EncodedJSValue* m_buffer;
        ListSet* m_markSet;

    private:
        // Prohibits new / delete, which would break GC.
        void* operator new(size_t size)
        {
            return fastMalloc(size);
        }
        void operator delete(void* p)
        {
            fastFree(p);
        }

        void* operator new[](size_t);
        void operator delete[](void*);

        void* operator new(size_t, void*);
        void operator delete(void*, size_t);
    };

    class ArgList {
        friend class JIT;
    public:
        ArgList()
            : m_args(0)
            , m_argCount(0)
        {
        }

        ArgList(ExecState* exec)
            : m_args(reinterpret_cast<JSValue*>(&exec[CallFrame::argumentOffset(0)]))
            , m_argCount(exec->argumentCount())
        {
        }

        ArgList(const MarkedArgumentBuffer& args)
            : m_args(reinterpret_cast<JSValue*>(args.m_buffer))
            , m_argCount(args.size())
        {
        }

        JSValue at(int i) const
        {
            if (i >= m_argCount)
                return jsUndefined();
            return m_args[-i];
        }

        bool isEmpty() const { return !m_argCount; }
        size_t size() const { return m_argCount; }
        
        JS_EXPORT_PRIVATE void getSlice(int startIndex, ArgList& result) const;

    private:
        JSValue* m_args;
        int m_argCount;
    };

} // namespace JSC

#endif // ArgList_h
