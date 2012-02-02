/*
 * Copyright (C) 2007-2008 Collabora Ltd.  All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 *
 * This is a internal include header for npapi.h
 *
 * Some of the #defines which are in X11 headers conflict with type and enum
 * names in JavaScriptCore and WebCore
 * This header #undefs those defines to fix the conflicts
 * If you need to include npapi.h or npruntime.h when building on X11,
 * include this file instead of the actual npapi.h or npruntime.h
 */

#include "npapi.h"
#include "npfunctions.h"
#include "npruntime.h"

#ifdef XP_UNIX
    #include <X11/Xresource.h>

    #undef None
    #undef Above
    #undef Below
    #undef Auto
    #undef Complex
    #undef Status
    #undef CursorShape
    #undef FocusIn
    #undef FocusOut
    #undef KeyPress
    #undef KeyRelease
    #undef Unsorted
    #undef Bool
    #undef FontChange
    #undef GrayScale
    #undef NormalState
    #undef True
    #undef False
    #undef Success
    #undef Expose
#endif
