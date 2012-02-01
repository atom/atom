/*
 *  Copyright (C) 2005, 2006, 2007, 2008, 2009, 2010 Apple Inc. All rights reserved.
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

// RefPtr and PassRefPtr are documented at http://webkit.org/coding/RefPtr.html

#ifndef WTF_RefPtr_h
#define WTF_RefPtr_h

#include <algorithm>
#include "FastAllocBase.h"
#include "PassRefPtr.h"

namespace WTF {

    enum PlacementNewAdoptType { PlacementNewAdopt };

    template<typename T> class PassRefPtr;
    template<typename T> class NonNullPassRefPtr;

    enum HashTableDeletedValueType { HashTableDeletedValue };

    template<typename T> class RefPtr {
        WTF_MAKE_FAST_ALLOCATED;
    public:
        ALWAYS_INLINE RefPtr() : m_ptr(0) { }
        ALWAYS_INLINE RefPtr(T* ptr) : m_ptr(ptr) { refIfNotNull(ptr); }
        ALWAYS_INLINE RefPtr(const RefPtr& o) : m_ptr(o.m_ptr) { refIfNotNull(m_ptr); }
        template<typename U> RefPtr(const RefPtr<U>& o) : m_ptr(o.get()) { refIfNotNull(m_ptr); }

        // See comments in PassRefPtr.h for an explanation of why these takes const references.
        template<typename U> RefPtr(const PassRefPtr<U>&);
        template<typename U> RefPtr(const NonNullPassRefPtr<U>&);

        // Special constructor for cases where we overwrite an object in place.
        ALWAYS_INLINE RefPtr(PlacementNewAdoptType) { }

        // Hash table deleted values, which are only constructed and never copied or destroyed.
        RefPtr(HashTableDeletedValueType) : m_ptr(hashTableDeletedValue()) { }
        bool isHashTableDeletedValue() const { return m_ptr == hashTableDeletedValue(); }

        ALWAYS_INLINE ~RefPtr() { derefIfNotNull(m_ptr); }

        T* get() const { return m_ptr; }
        
        void clear();
        PassRefPtr<T> release() { PassRefPtr<T> tmp = adoptRef(m_ptr); m_ptr = 0; return tmp; }

        T& operator*() const { return *m_ptr; }
        ALWAYS_INLINE T* operator->() const { return m_ptr; }
        
        bool operator!() const { return !m_ptr; }
    
        // This conversion operator allows implicit conversion to bool but not to other integer types.
        typedef T* (RefPtr::*UnspecifiedBoolType);
        operator UnspecifiedBoolType() const { return m_ptr ? &RefPtr::m_ptr : 0; }
        
        RefPtr& operator=(const RefPtr&);
        RefPtr& operator=(T*);
        RefPtr& operator=(const PassRefPtr<T>&);
        RefPtr& operator=(const NonNullPassRefPtr<T>&);
#if !COMPILER_SUPPORTS(CXX_NULLPTR)
        RefPtr& operator=(std::nullptr_t) { clear(); return *this; }
#endif
        template<typename U> RefPtr& operator=(const RefPtr<U>&);
        template<typename U> RefPtr& operator=(const PassRefPtr<U>&);
        template<typename U> RefPtr& operator=(const NonNullPassRefPtr<U>&);

        void swap(RefPtr&);

        static T* hashTableDeletedValue() { return reinterpret_cast<T*>(-1); }

    private:
        T* m_ptr;
    };
    
    template<typename T> template<typename U> inline RefPtr<T>::RefPtr(const PassRefPtr<U>& o)
        : m_ptr(o.leakRef())
    {
    }

    template<typename T> template<typename U> inline RefPtr<T>::RefPtr(const NonNullPassRefPtr<U>& o)
        : m_ptr(o.leakRef())
    {
    }

    template<typename T> inline void RefPtr<T>::clear()
    {
        T* ptr = m_ptr;
        m_ptr = 0;
        derefIfNotNull(ptr);
    }

    template<typename T> inline RefPtr<T>& RefPtr<T>::operator=(const RefPtr<T>& o)
    {
        T* optr = o.get();
        refIfNotNull(optr);
        T* ptr = m_ptr;
        m_ptr = optr;
        derefIfNotNull(ptr);
        return *this;
    }
    
    template<typename T> template<typename U> inline RefPtr<T>& RefPtr<T>::operator=(const RefPtr<U>& o)
    {
        T* optr = o.get();
        refIfNotNull(optr);
        T* ptr = m_ptr;
        m_ptr = optr;
        derefIfNotNull(ptr);
        return *this;
    }
    
    template<typename T> inline RefPtr<T>& RefPtr<T>::operator=(T* optr)
    {
        refIfNotNull(optr);
        T* ptr = m_ptr;
        m_ptr = optr;
        derefIfNotNull(ptr);
        return *this;
    }

    template<typename T> inline RefPtr<T>& RefPtr<T>::operator=(const PassRefPtr<T>& o)
    {
        T* ptr = m_ptr;
        m_ptr = o.leakRef();
        derefIfNotNull(ptr);
        return *this;
    }

    template<typename T> inline RefPtr<T>& RefPtr<T>::operator=(const NonNullPassRefPtr<T>& o)
    {
        T* ptr = m_ptr;
        m_ptr = o.leakRef();
        derefIfNotNull(ptr);
        return *this;
    }

    template<typename T> template<typename U> inline RefPtr<T>& RefPtr<T>::operator=(const PassRefPtr<U>& o)
    {
        T* ptr = m_ptr;
        m_ptr = o.leakRef();
        derefIfNotNull(ptr);
        return *this;
    }

    template<typename T> template<typename U> inline RefPtr<T>& RefPtr<T>::operator=(const NonNullPassRefPtr<U>& o)
    {
        T* ptr = m_ptr;
        m_ptr = o.leakRef();
        derefIfNotNull(ptr);
        return *this;
    }

    template<class T> inline void RefPtr<T>::swap(RefPtr<T>& o)
    {
        std::swap(m_ptr, o.m_ptr);
    }

    template<class T> inline void swap(RefPtr<T>& a, RefPtr<T>& b)
    {
        a.swap(b);
    }

    template<typename T, typename U> inline bool operator==(const RefPtr<T>& a, const RefPtr<U>& b)
    { 
        return a.get() == b.get(); 
    }

    template<typename T, typename U> inline bool operator==(const RefPtr<T>& a, U* b)
    { 
        return a.get() == b; 
    }
    
    template<typename T, typename U> inline bool operator==(T* a, const RefPtr<U>& b) 
    {
        return a == b.get(); 
    }
    
    template<typename T, typename U> inline bool operator!=(const RefPtr<T>& a, const RefPtr<U>& b)
    { 
        return a.get() != b.get(); 
    }

    template<typename T, typename U> inline bool operator!=(const RefPtr<T>& a, U* b)
    {
        return a.get() != b; 
    }

    template<typename T, typename U> inline bool operator!=(T* a, const RefPtr<U>& b)
    { 
        return a != b.get(); 
    }
    
    template<typename T, typename U> inline RefPtr<T> static_pointer_cast(const RefPtr<U>& p)
    { 
        return RefPtr<T>(static_cast<T*>(p.get())); 
    }

    template<typename T, typename U> inline RefPtr<T> const_pointer_cast(const RefPtr<U>& p)
    { 
        return RefPtr<T>(const_cast<T*>(p.get())); 
    }

    template<typename T> inline T* getPtr(const RefPtr<T>& p)
    {
        return p.get();
    }

} // namespace WTF

using WTF::RefPtr;
using WTF::static_pointer_cast;
using WTF::const_pointer_cast;

#endif // WTF_RefPtr_h
