/*
 * Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
 * Copyright (C) 2006 Samuel Weinig <sam.weinig@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#import <WebKit/DOMObject.h>

#if WEBKIT_VERSION_MAX_ALLOWED >= WEBKIT_VERSION_LATEST

@class NSString;

enum {
    DOM_PATHSEG_UNKNOWN = 0,
    DOM_PATHSEG_CLOSEPATH = 1,
    DOM_PATHSEG_MOVETO_ABS = 2,
    DOM_PATHSEG_MOVETO_REL = 3,
    DOM_PATHSEG_LINETO_ABS = 4,
    DOM_PATHSEG_LINETO_REL = 5,
    DOM_PATHSEG_CURVETO_CUBIC_ABS = 6,
    DOM_PATHSEG_CURVETO_CUBIC_REL = 7,
    DOM_PATHSEG_CURVETO_QUADRATIC_ABS = 8,
    DOM_PATHSEG_CURVETO_QUADRATIC_REL = 9,
    DOM_PATHSEG_ARC_ABS = 10,
    DOM_PATHSEG_ARC_REL = 11,
    DOM_PATHSEG_LINETO_HORIZONTAL_ABS = 12,
    DOM_PATHSEG_LINETO_HORIZONTAL_REL = 13,
    DOM_PATHSEG_LINETO_VERTICAL_ABS = 14,
    DOM_PATHSEG_LINETO_VERTICAL_REL = 15,
    DOM_PATHSEG_CURVETO_CUBIC_SMOOTH_ABS = 16,
    DOM_PATHSEG_CURVETO_CUBIC_SMOOTH_REL = 17,
    DOM_PATHSEG_CURVETO_QUADRATIC_SMOOTH_ABS = 18,
    DOM_PATHSEG_CURVETO_QUADRATIC_SMOOTH_REL = 19
};

@interface DOMSVGPathSeg : DOMObject
@property(readonly) unsigned short pathSegType;
@property(readonly, copy) NSString *pathSegTypeAsLetter;
@end

#endif
