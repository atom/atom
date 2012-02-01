/*
 *  Copyright (C) 2004, 2008, 2009 Apple Inc. All rights reserved.
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


#ifndef Protect_h
#define Protect_h

#include "Heap.h"
#include "JSValue.h"

namespace JSC {

    inline void gcProtect(JSCell* val) 
    {
        Heap::heap(val)->protect(val);
    }

    inline void gcUnprotect(JSCell* val)
    {
        Heap::heap(val)->unprotect(val);
    }

    inline void gcProtectNullTolerant(JSCell* val) 
    {
        if (val) 
            gcProtect(val);
    }

    inline void gcUnprotectNullTolerant(JSCell* val) 
    {
        if (val) 
            gcUnprotect(val);
    }
    
    inline void gcProtect(JSValue value)
    {
        if (value && value.isCell())
            gcProtect(value.asCell());
    }

    inline void gcUnprotect(JSValue value)
    {
        if (value && value.isCell())
            gcUnprotect(value.asCell());
    }

} // namespace JSC

#endif // Protect_h
