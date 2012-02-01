/*
 * Copyright (C) 2007 Apple Inc.  All rights reserved.
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


#ifndef DragClient_h
#define DragClient_h

#include "DragActions.h"
#include "DragImage.h"
#include "IntPoint.h"

#if PLATFORM(MAC)
OBJC_CLASS DOMElement;
OBJC_CLASS NSURL;
OBJC_CLASS NSString;
OBJC_CLASS NSPasteboard;
#endif

namespace WebCore {
    
    class Clipboard;
    class DragData;
    class Frame;
    class Image;
    class HTMLImageElement;
    
    class DragClient {
    public:
        virtual void willPerformDragDestinationAction(DragDestinationAction, DragData*) = 0;
        virtual void willPerformDragSourceAction(DragSourceAction, const IntPoint&, Clipboard*) = 0;
        virtual DragDestinationAction actionMaskForDrag(DragData*) = 0;

        virtual DragSourceAction dragSourceActionMaskForPoint(const IntPoint& rootViewPoint) = 0;
        
        virtual void startDrag(DragImageRef dragImage, const IntPoint& dragImageOrigin, const IntPoint& eventPos, Clipboard*, Frame*, bool linkDrag = false) = 0;
        
        virtual void dragControllerDestroyed() = 0;

#if PLATFORM(MAC)
        // Mac-specific helper function to allow access to web archives and NSPasteboard extras in WebKit.
        // This is not abstract as that would require another #if PLATFORM(MAC) for the SVGImage client empty implentation.
        virtual void declareAndWriteDragImage(NSPasteboard *, DOMElement*, NSURL *, NSString *, Frame*) { }
#endif
        
        virtual void dragEnded() { }

        virtual ~DragClient() { }
    };
    
}

#endif // !DragClient_h

