/*
 Copyright (C) 2010 Nokia Corporation and/or its subsidiary(-ies)
 
 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Library General Public
 License as published by the Free Software Foundation; either
 version 2 of the License, or (at your option) any later version.
 
 This library is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 Library General Public License for more details.
 
 You should have received a copy of the GNU Library General Public License
 along with this library; see the file COPYING.LIB.  If not, write to
 the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 Boston, MA 02110-1301, USA.
 */

#ifndef IntPointHash_h
#define IntPointHash_h

#include "IntPoint.h"
#include <wtf/HashFunctions.h>
#include <wtf/HashTraits.h>

namespace WTF {
    
// The empty value is (0, INT_MIN), the deleted value is (INT_MIN, 0)
struct IntPointHash {
    static unsigned hash(const WebCore::IntPoint& p) { return WTF::intHash(static_cast<uint64_t>(p.x()) << 32 | p.y()); }
    static bool equal(const WebCore::IntPoint& a, const WebCore::IntPoint& b) { return a == b; }
    static const bool safeToCompareToEmptyOrDeleted = true;
};
template<> struct HashTraits<WebCore::IntPoint> : GenericHashTraits<WebCore::IntPoint> {
    static const bool needsDestruction = false;
    static WebCore::IntPoint emptyValue() { return WebCore::IntPoint(0, std::numeric_limits<int>::min()); }
    
    static void constructDeletedValue(WebCore::IntPoint& slot) { slot = WebCore::IntPoint(std::numeric_limits<int>::min(), 0); }
    static bool isDeletedValue(const WebCore::IntPoint& slot) { return slot == WebCore::IntPoint(std::numeric_limits<int>::min(), 0); }
};
template<> struct DefaultHash<WebCore::IntPoint> {
    typedef IntPointHash Hash;
};

}

#endif
