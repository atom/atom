/*
 * Copyright (C) 2007, 2009 Apple Inc. All rights reserved.
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

#ifndef DragController_h
#define DragController_h

#include "DragActions.h"
#include "DragImage.h"
#include "IntPoint.h"
#include "KURL.h"

namespace WebCore {

    class Clipboard;
    class Document;
    class DragClient;
    class DragData;
    struct DragSession;
    struct DragState;
    class Element;
    class Frame;
    class FrameSelection;
    class HTMLInputElement;
    class Image;
    class IntRect;
    class Node;
    class Page;
    class PlatformMouseEvent;
    class Range;
    
    class DragController {
        WTF_MAKE_NONCOPYABLE(DragController); WTF_MAKE_FAST_ALLOCATED;
    public:
        ~DragController();

        static PassOwnPtr<DragController> create(Page*, DragClient*);

        DragClient* client() const { return m_client; }

        DragSession dragEntered(DragData*);
        void dragExited(DragData*);
        DragSession dragUpdated(DragData*);
        bool performDrag(DragData*);
        
        // FIXME: It should be possible to remove a number of these accessors once all
        // drag logic is in WebCore.
        void setDidInitiateDrag(bool initiated) { m_didInitiateDrag = initiated; } 
        bool didInitiateDrag() const { return m_didInitiateDrag; }
        void setIsHandlingDrag(bool handling) { m_isHandlingDrag = handling; }
        bool isHandlingDrag() const { return m_isHandlingDrag; }
        DragOperation sourceDragOperation() const { return m_sourceDragOperation; }
        const KURL& draggingImageURL() const { return m_draggingImageURL; }
        void setDragOffset(const IntPoint& offset) { m_dragOffset = offset; }
        const IntPoint& dragOffset() const { return m_dragOffset; }
        DragSourceAction dragSourceAction() const { return m_dragSourceAction; }

        Document* documentUnderMouse() const { return m_documentUnderMouse.get(); }
        DragDestinationAction dragDestinationAction() const { return m_dragDestinationAction; }
        DragSourceAction delegateDragSourceAction(const IntPoint& rootViewPoint);
        
        Node* draggableNode(const Frame*, Node*, const IntPoint&, DragState&) const;
        void dragEnded();
        
        void placeDragCaret(const IntPoint&);
        
        bool startDrag(Frame* src, const DragState&, DragOperation srcOp, const PlatformMouseEvent& dragEvent, const IntPoint& dragOrigin);
        static const IntSize& maxDragImageSize();
        
        static const int LinkDragBorderInset;
        static const int MaxOriginalImageArea;
        static const int DragIconRightInset;
        static const int DragIconBottomInset;        
        static const float DragImageAlpha;

    private:
        DragController(Page*, DragClient*);

        bool dispatchTextInputEventFor(Frame*, DragData*);
        bool canProcessDrag(DragData*);
        bool concludeEditDrag(DragData*);
        DragSession dragEnteredOrUpdated(DragData*);
        DragOperation operationForLoad(DragData*);
        bool tryDocumentDrag(DragData*, DragDestinationAction, DragSession&);
        bool tryDHTMLDrag(DragData*, DragOperation&);
        DragOperation dragOperation(DragData*);
        void cancelDrag();
        bool dragIsMove(FrameSelection*, DragData*);
        bool isCopyKeyDown(DragData*);

        void mouseMovedIntoDocument(Document*);

        IntRect selectionDraggingRect(Frame*);
        bool doDrag(Frame* src, Clipboard* clipboard, DragImageRef dragImage, const KURL& linkURL, const KURL& imageURL, Node* node, IntPoint& dragLoc, IntPoint& dragImageOffset);
        void doImageDrag(Element*, const IntPoint&, const IntRect&, Clipboard*, Frame*, IntPoint&);
        void doSystemDrag(DragImageRef, const IntPoint&, const IntPoint&, Clipboard*, Frame*, bool forLink);
        void cleanupAfterSystemDrag();

        Page* m_page;
        DragClient* m_client;
        
        RefPtr<Document> m_documentUnderMouse; // The document the mouse was last dragged over.
        RefPtr<Document> m_dragInitiator; // The Document (if any) that initiated the drag.
        RefPtr<HTMLInputElement> m_fileInputElementUnderMouse;
        
        DragDestinationAction m_dragDestinationAction;
        DragSourceAction m_dragSourceAction;
        bool m_didInitiateDrag;
        bool m_isHandlingDrag;
        DragOperation m_sourceDragOperation; // Set in startDrag when a drag starts from a mouse down within WebKit
        IntPoint m_dragOffset;
        KURL m_draggingImageURL;
    };

}

#endif
