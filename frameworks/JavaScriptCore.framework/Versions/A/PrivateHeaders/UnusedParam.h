/*
 *  Copyright (C) 2006 Apple Computer, Inc.
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

#ifndef WTF_UnusedParam_h
#define WTF_UnusedParam_h

/* don't use this for C++, it should only be used in plain C files or
   ObjC methods, where leaving off the parameter name is not allowed. */

#include "Platform.h"

#if COMPILER(INTEL) && !OS(WINDOWS) || COMPILER(RVCT)
template<typename T>
inline void unusedParam(T& x) { (void)x; }
#define UNUSED_PARAM(variable) unusedParam(variable)
#else
#define UNUSED_PARAM(variable) (void)variable
#endif

#endif /* WTF_UnusedParam_h */
