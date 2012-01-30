/*
 * Copyright (C) 2003, 2009 Apple Inc.  All rights reserved.
 *
 * Portions are Copyright (C) 1998 Netscape Communications Corporation.
 *
 * Other contributors:
 *   Robert O'Callahan <roc+@cs.cmu.edu>
 *   David Baron <dbaron@fas.harvard.edu>
 *   Christian Biesinger <cbiesinger@web.de>
 *   Randall Jesup <rjesup@wgate.com>
 *   Roland Mainz <roland.mainz@informatik.med.uni-giessen.de>
 *   Josh Soref <timeless@mac.com>
 *   Boris Zbarsky <bzbarsky@mit.edu>
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
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * Alternatively, the contents of this file may be used under the terms
 * of either the Mozilla Public License Version 1.1, found at
 * http://www.mozilla.org/MPL/ (the "MPL") or the GNU General Public
 * License Version 2.0, found at http://www.fsf.org/copyleft/gpl.html
 * (the "GPL"), in which case the provisions of the MPL or the GPL are
 * applicable instead of those above.  If you wish to allow use of your
 * version of this file only under the terms of one of those two
 * licenses (the MPL or the GPL) and not to allow others to use your
 * version of this file under the LGPL, indicate your decision by
 * deletingthe provisions above and replace them with the notice and
 * other provisions required by the MPL or the GPL, as the case may be.
 * If you do not delete the provisions above, a recipient may use your
 * version of this file under any of the LGPL, the MPL or the GPL.
 */

#ifndef ScrollBehavior_h
#define ScrollBehavior_h

namespace WebCore {

enum ScrollBehavior {
    noScroll,
    alignCenter,
    alignTop,
    alignBottom, 
    alignLeft,
    alignRight,
    alignToClosestEdge
};

struct ScrollAlignment {
    static ScrollBehavior getVisibleBehavior(const ScrollAlignment& s) { return s.m_rectVisible; }
    static ScrollBehavior getPartialBehavior(const ScrollAlignment& s) { return s.m_rectPartial; }
    static ScrollBehavior getHiddenBehavior(const ScrollAlignment& s) { return s.m_rectHidden; }

    static const ScrollAlignment alignCenterIfNeeded;
    static const ScrollAlignment alignToEdgeIfNeeded;
    static const ScrollAlignment alignCenterAlways;
    static const ScrollAlignment alignTopAlways;
    static const ScrollAlignment alignBottomAlways;

    ScrollBehavior m_rectVisible;
    ScrollBehavior m_rectHidden;
    ScrollBehavior m_rectPartial;
};


}; // namespace WebCore

#endif // ScrollBehavior_h
