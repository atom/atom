/*
 * Copyright (C) 2006 Apple Computer, Inc.  All rights reserved.
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

#ifndef ScrollTypes_h
#define ScrollTypes_h

namespace WebCore {

    enum ScrollDirection {
        ScrollUp,
        ScrollDown,
        ScrollLeft,
        ScrollRight
    };

    enum ScrollLogicalDirection {
        ScrollBlockDirectionBackward,
        ScrollBlockDirectionForward,
        ScrollInlineDirectionBackward,
        ScrollInlineDirectionForward
    };
    
    
    inline ScrollDirection logicalToPhysical(ScrollLogicalDirection direction, bool isVertical, bool isFlipped) 
    {
        switch (direction) {
        case ScrollBlockDirectionBackward: {
            if (isVertical) {
                if (!isFlipped)
                    return ScrollUp;
                return ScrollDown;
            } else {
                if (!isFlipped)
                    return ScrollLeft;
                return ScrollRight;
            }
            break;
        }
        case ScrollBlockDirectionForward: {
            if (isVertical) {
                if (!isFlipped)
                    return ScrollDown;
                return ScrollUp;
            } else {
                if (!isFlipped)
                    return ScrollRight;
                return ScrollLeft;
            }
            break;
        }
        case ScrollInlineDirectionBackward: {
            if (isVertical) {
                if (!isFlipped)
                    return ScrollLeft;
                return ScrollRight;
            } else {
                if (!isFlipped)
                    return ScrollUp;
                return ScrollDown;
            }
            break;
        }
        case ScrollInlineDirectionForward: {
            if (isVertical) {
                if (!isFlipped)
                    return ScrollRight;
                return ScrollLeft;
            } else {
                if (!isFlipped)
                    return ScrollDown;
                return ScrollUp;
            }
            break;
        }
        default:
            ASSERT_NOT_REACHED();
            break;
        }
        return ScrollUp;
    }

    enum ScrollGranularity {
        ScrollByLine,
        ScrollByPage,
        ScrollByDocument,
        ScrollByPixel
    };

    enum ScrollElasticity {
        ScrollElasticityAutomatic,
        ScrollElasticityNone,
        ScrollElasticityAllowed
    };

    enum ScrollbarOrientation { HorizontalScrollbar, VerticalScrollbar };

    enum ScrollbarMode { ScrollbarAuto, ScrollbarAlwaysOff, ScrollbarAlwaysOn };

    enum ScrollbarControlSize { RegularScrollbar, SmallScrollbar };

    typedef unsigned ScrollbarControlState;

    enum ScrollbarControlStateMask {
        ActiveScrollbarState = 1,
        EnabledScrollbarState = 1 << 1,
        PressedScrollbarState = 1 << 2
    };

    enum ScrollbarPart {
        NoPart = 0,
        BackButtonStartPart = 1,
        ForwardButtonStartPart = 1 << 1,
        BackTrackPart = 1 << 2,
        ThumbPart = 1 << 3,
        ForwardTrackPart = 1 << 4,
        BackButtonEndPart = 1 << 5,
        ForwardButtonEndPart = 1 << 6,
        ScrollbarBGPart = 1 << 7,
        TrackBGPart = 1 << 8,
        AllParts = 0xffffffff
    };

    enum ScrollbarButtonsPlacement {
        ScrollbarButtonsNone,
        ScrollbarButtonsSingle,
        ScrollbarButtonsDoubleStart,
        ScrollbarButtonsDoubleEnd,
        ScrollbarButtonsDoubleBoth
    };
    
    enum ScrollbarOverlayStyle {
        ScrollbarOverlayStyleDefault,
        ScrollbarOverlayStyleDark,
        ScrollbarOverlayStyleLight
    };
    
    typedef unsigned ScrollbarControlPartMask;

}

#endif
