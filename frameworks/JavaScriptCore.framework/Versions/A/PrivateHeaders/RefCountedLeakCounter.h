/*
 *  Copyright (C) 2008 Apple Inc. All rights reserved.
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
 
#ifndef RefCountedLeakCounter_h
#define RefCountedLeakCounter_h
 
#include "Assertions.h"
#include "Threading.h"

namespace WTF {
    
    struct RefCountedLeakCounter {
        WTF_EXPORT_PRIVATE static void suppressMessages(const char*);
        WTF_EXPORT_PRIVATE static void cancelMessageSuppression(const char*);
        
        WTF_EXPORT_PRIVATE explicit RefCountedLeakCounter(const char* description);
        WTF_EXPORT_PRIVATE ~RefCountedLeakCounter();

        WTF_EXPORT_PRIVATE void increment();
        WTF_EXPORT_PRIVATE void decrement();

#ifndef NDEBUG
    private:
#if COMPILER(MINGW) || COMPILER(MSVC7_OR_LOWER) || OS(WINCE)
        int m_count;
#else
        volatile int m_count;
#endif
        const char* m_description;
#endif
    };

}  // namespace WTF

#endif
