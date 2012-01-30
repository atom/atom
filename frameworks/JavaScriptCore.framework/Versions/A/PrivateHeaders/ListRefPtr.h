/*
 *  Copyright (C) 2005, 2006, 2008 Apple Inc. All rights reserved.
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

#ifndef WTF_ListRefPtr_h
#define WTF_ListRefPtr_h

#include <wtf/RefPtr.h>

namespace WTF {

    // Specialized version of RefPtr desgined for use in singly-linked lists. 
    // Derefs the list iteratively to avoid recursive derefing that can overflow the stack.
    template <typename T> class ListRefPtr : public RefPtr<T> {
    public:
        ListRefPtr() : RefPtr<T>() {}
        ListRefPtr(T* ptr) : RefPtr<T>(ptr) {}
        ListRefPtr(const RefPtr<T>& o) : RefPtr<T>(o) {}
        // see comment in PassRefPtr.h for why this takes const reference
        template <typename U> ListRefPtr(const PassRefPtr<U>& o) : RefPtr<T>(o) {}
        
        ~ListRefPtr()
        {
            RefPtr<T> reaper = this->release();
            while (reaper && reaper->hasOneRef())
                reaper = reaper->releaseNext(); // implicitly protects reaper->next, then derefs reaper
        }
        
        ListRefPtr& operator=(T* optr) { RefPtr<T>::operator=(optr); return *this; }
        ListRefPtr& operator=(const RefPtr<T>& o) { RefPtr<T>::operator=(o); return *this; }
        ListRefPtr& operator=(const PassRefPtr<T>& o) { RefPtr<T>::operator=(o); return *this; }
        template <typename U> ListRefPtr& operator=(const RefPtr<U>& o) { RefPtr<T>::operator=(o); return *this; }
        template <typename U> ListRefPtr& operator=(const PassRefPtr<U>& o) { RefPtr<T>::operator=(o); return *this; }
    };

    template <typename T> inline T* getPtr(const ListRefPtr<T>& p)
    {
        return p.get();
    }

} // namespace WTF

using WTF::ListRefPtr;

#endif // WTF_ListRefPtr_h
