/*
 *  Copyright (C) 2006, 2010 Apple Inc. All rights reserved.
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

#ifndef WTF_OwnArrayPtr_h
#define WTF_OwnArrayPtr_h

#include "Assertions.h"
#include "Noncopyable.h"
#include "NullPtr.h"
#include "PassOwnArrayPtr.h"
#include <algorithm>

namespace WTF {

template<typename T> class PassOwnArrayPtr;
template<typename T> PassOwnArrayPtr<T> adoptArrayPtr(T*);

template <typename T> class OwnArrayPtr {
public:
    typedef T* PtrType;

    OwnArrayPtr() : m_ptr(0) { }

    // See comment in PassOwnArrayPtr.h for why this takes a const reference.
    template<typename U> OwnArrayPtr(const PassOwnArrayPtr<U>& o);

    // This copy constructor is used implicitly by gcc when it generates
    // transients for assigning a PassOwnArrayPtr<T> object to a stack-allocated
    // OwnArrayPtr<T> object. It should never be called explicitly and gcc
    // should optimize away the constructor when generating code.
    OwnArrayPtr(const OwnArrayPtr<T>&);

    ~OwnArrayPtr() { deleteOwnedArrayPtr(m_ptr); }

    PtrType get() const { return m_ptr; }

    void clear();
    PassOwnArrayPtr<T> release();
    PtrType leakPtr() WARN_UNUSED_RETURN;

    T& operator*() const { ASSERT(m_ptr); return *m_ptr; }
    PtrType operator->() const { ASSERT(m_ptr); return m_ptr; }

    T& operator[](std::ptrdiff_t i) const { ASSERT(m_ptr); ASSERT(i >= 0); return m_ptr[i]; }

    bool operator!() const { return !m_ptr; }

    // This conversion operator allows implicit conversion to bool but not to other integer types.
    typedef T* OwnArrayPtr::*UnspecifiedBoolType;
    operator UnspecifiedBoolType() const { return m_ptr ? &OwnArrayPtr::m_ptr : 0; }

    OwnArrayPtr& operator=(const PassOwnArrayPtr<T>&);
    OwnArrayPtr& operator=(std::nullptr_t) { clear(); return *this; }
    template<typename U> OwnArrayPtr& operator=(const PassOwnArrayPtr<U>&);

    void swap(OwnArrayPtr& o) { std::swap(m_ptr, o.m_ptr); }

private:
    PtrType m_ptr;
};

template<typename T> template<typename U> inline OwnArrayPtr<T>::OwnArrayPtr(const PassOwnArrayPtr<U>& o)
    : m_ptr(o.leakPtr())
{
}

template<typename T> inline void OwnArrayPtr<T>::clear()
{
    PtrType ptr = m_ptr;
    m_ptr = 0;
    deleteOwnedArrayPtr(ptr);
}

template<typename T> inline PassOwnArrayPtr<T> OwnArrayPtr<T>::release()
{
    PtrType ptr = m_ptr;
    m_ptr = 0;
    return adoptArrayPtr(ptr);
}

template<typename T> inline typename OwnArrayPtr<T>::PtrType OwnArrayPtr<T>::leakPtr()
{
    PtrType ptr = m_ptr;
    m_ptr = 0;
    return ptr;
}

template<typename T> inline OwnArrayPtr<T>& OwnArrayPtr<T>::operator=(const PassOwnArrayPtr<T>& o)
{
    PtrType ptr = m_ptr;
    m_ptr = o.leakPtr();
    ASSERT(!ptr || m_ptr != ptr);
    deleteOwnedArrayPtr(ptr);
    return *this;
}

template<typename T> template<typename U> inline OwnArrayPtr<T>& OwnArrayPtr<T>::operator=(const PassOwnArrayPtr<U>& o)
{
    PtrType ptr = m_ptr;
    m_ptr = o.leakPtr();
    ASSERT(!ptr || m_ptr != ptr);
    deleteOwnedArrayPtr(ptr);
    return *this;
}

template <typename T> inline void swap(OwnArrayPtr<T>& a, OwnArrayPtr<T>& b)
{
    a.swap(b);
}

template<typename T, typename U> inline bool operator==(const OwnArrayPtr<T>& a, U* b)
{
    return a.get() == b; 
}

template<typename T, typename U> inline bool operator==(T* a, const OwnArrayPtr<U>& b) 
{
    return a == b.get(); 
}

template<typename T, typename U> inline bool operator!=(const OwnArrayPtr<T>& a, U* b)
{
    return a.get() != b; 
}

template<typename T, typename U> inline bool operator!=(T* a, const OwnArrayPtr<U>& b)
{
    return a != b.get(); 
}

template <typename T> inline T* getPtr(const OwnArrayPtr<T>& p)
{
    return p.get();
}

} // namespace WTF

using WTF::OwnArrayPtr;

#endif // WTF_OwnArrayPtr_h
