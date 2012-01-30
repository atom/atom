/*
 * Copyright (C) 2001 Peter Kelly (pmk@post.com)
 * Copyright (C) 2001 Tobias Anton (anton@stud.fbi.fh-darmstadt.de)
 * Copyright (C) 2006 Samuel Weinig (sam.weinig@gmail.com)
 * Copyright (C) 2003, 2004, 2005, 2006, 2008 Apple Inc. All rights reserved.
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
 *
 */

#ifndef Clipboard_h
#define Clipboard_h

#include "CachedResourceHandle.h"
#include "ClipboardAccessPolicy.h"
#include "DragActions.h"
#include "DragImage.h"
#include "IntPoint.h"
#include "Node.h"

namespace WebCore {

    class DataTransferItemList;
    class DragData;
    class FileList;
    class Frame;

    // State available during IE's events for drag and drop and copy/paste
    class Clipboard : public RefCounted<Clipboard> {
    public:
        // Whether this clipboard is serving a drag-drop or copy-paste request.
        enum ClipboardType {
            CopyAndPaste,
            DragAndDrop,
        };
        
        static PassRefPtr<Clipboard> create(ClipboardAccessPolicy, DragData*, Frame*);

        virtual ~Clipboard() { }

        bool isForCopyAndPaste() const { return m_clipboardType == CopyAndPaste; }
        bool isForDragAndDrop() const { return m_clipboardType == DragAndDrop; }

        String dropEffect() const { return dropEffectIsUninitialized() ? "none" : m_dropEffect; }
        void setDropEffect(const String&);
        bool dropEffectIsUninitialized() const { return m_dropEffect == "uninitialized"; }
        String effectAllowed() const { return m_effectAllowed; }
        void setEffectAllowed(const String&);
    
        virtual void clearData(const String& type) = 0;
        virtual void clearAllData() = 0;
        virtual String getData(const String& type, bool& success) const = 0;
        virtual bool setData(const String& type, const String& data) = 0;
    
        // extensions beyond IE's API
        virtual HashSet<String> types() const = 0;
        virtual PassRefPtr<FileList> files() const = 0;

        LayoutPoint dragLocation() const { return m_dragLoc; }
        CachedImage* dragImage() const { return m_dragImage.get(); }
        virtual void setDragImage(CachedImage*, const LayoutPoint&) = 0;
        Node* dragImageElement() const { return m_dragImageElement.get(); }
        virtual void setDragImageElement(Node*, const LayoutPoint&) = 0;
        
        virtual DragImageRef createDragImage(LayoutPoint& dragLocation) const = 0;
#if ENABLE(DRAG_SUPPORT)
        virtual void declareAndWriteDragImage(Element*, const KURL&, const String& title, Frame*) = 0;
#endif
        virtual void writeURL(const KURL&, const String&, Frame*) = 0;
        virtual void writeRange(Range*, Frame*) = 0;
        virtual void writePlainText(const String&) = 0;

        virtual bool hasData() = 0;
        
        void setAccessPolicy(ClipboardAccessPolicy);
        ClipboardAccessPolicy policy() const { return m_policy; }

        DragOperation sourceOperation() const;
        DragOperation destinationOperation() const;
        void setSourceOperation(DragOperation);
        void setDestinationOperation(DragOperation);
        
        bool hasDropZoneType(const String&);
        
        void setDragHasStarted() { m_dragStarted = true; }

#if ENABLE(DATA_TRANSFER_ITEMS)
        virtual PassRefPtr<DataTransferItemList> items() = 0;
#endif
        
    protected:
        Clipboard(ClipboardAccessPolicy, ClipboardType);

        bool dragStarted() const { return m_dragStarted; }
        
    private:
        bool hasFileOfType(const String&) const;
        bool hasStringOfType(const String&) const;
        
        ClipboardAccessPolicy m_policy;
        String m_dropEffect;
        String m_effectAllowed;
        bool m_dragStarted;
        ClipboardType m_clipboardType;
        
    protected:
        LayoutPoint m_dragLoc;
        CachedResourceHandle<CachedImage> m_dragImage;
        RefPtr<Node> m_dragImageElement;
    };

    DragOperation convertDropZoneOperationToDragOperation(const String& dragOperation);
    String convertDragOperationToDropZoneOperation(DragOperation);
    
} // namespace WebCore

#endif // Clipboard_h
