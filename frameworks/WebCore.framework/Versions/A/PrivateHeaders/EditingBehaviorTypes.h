/*
 * Copyright (C) 2010 Nokia Corporation and/or its subsidiary(-ies)
 * Copyright (C) 2010 Apple Inc. All rights reserved.
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

#ifndef EditingBehaviorTypes_h
#define EditingBehaviorTypes_h

namespace WebCore {

// There are multiple editing details that are different on Windows than Macintosh.
// We use a single switch for all of them. Some examples:
//
//    1) Clicking below the last line of an editable area puts the caret at the end
//       of the last line on Mac, but in the middle of the last line on Windows.
//    2) Pushing the down arrow key on the last line puts the caret at the end of the
//       last line on Mac, but does nothing on Windows. A similar case exists on the
//       top line.
//
// This setting is intended to control these sorts of behaviors. There are some other
// behaviors with individual function calls on EditorClient (smart copy and paste and
// selecting the space after a double click) that could be combined with this if
// if possible in the future.
enum EditingBehaviorType {
    EditingMacBehavior,
    EditingWindowsBehavior,
    EditingUnixBehavior
};

} // WebCore namespace

#endif // EditingBehaviorTypes_h
