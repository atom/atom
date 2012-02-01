/*
 * Copyright (C) 2004, 2005, 2006, 2007, 2008 Nikolas Zimmermann <zimmermann@kde.org>
 * Copyright (C) Research In Motion Limited 2010. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#ifndef SVGPropertyTraits_h
#define SVGPropertyTraits_h

#if ENABLE(SVG)
#include <wtf/text/WTFString.h>

namespace WebCore {

template<typename PropertyType>
struct SVGPropertyTraits { };

template<>
struct SVGPropertyTraits<bool> {
    static bool initialValue() { return false; }
    static String toString(bool type) { return type ? "true" : "false"; }
};

template<>
struct SVGPropertyTraits<int> {
    static int initialValue() { return 0; }
    static String toString(int type) { return String::number(type); }
};

template<>
struct SVGPropertyTraits<long> {
    static long initialValue() { return 0; }
    static String toString(long type) { return String::number(type); }
};

template<>
struct SVGPropertyTraits<float> {
    static float initialValue() { return 0; }
    static String toString(float type) { return String::number(type); }
};

template<>
struct SVGPropertyTraits<String> {
    static String initialValue() { return String(); }
    static String toString(const String& type) { return type; }
};

}

#endif
#endif
