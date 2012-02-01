/*
 * Copyright (C) 2004, 2006, 2008 Apple Inc. All rights reserved.
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

#ifndef ClipboardMac_h
#define ClipboardMac_h

#include "CachedImage.h"
#include "Clipboard.h"
#include <wtf/RetainPtr.h>

OBJC_CLASS NSImage;
OBJC_CLASS NSPasteboard;

namespace WebCore {

class Frame;
class FileList;

class ClipboardMac : public Clipboard, public CachedImageClient {
    WTF_MAKE_FAST_ALLOCATED;
public:
    static PassRefPtr<ClipboardMac> create(ClipboardType clipboardType, NSPasteboard *pasteboard, ClipboardAccessPolicy policy, Frame* frame)
    {
        return adoptRef(new ClipboardMac(clipboardType, pasteboard, policy, frame));
    }

    virtual ~ClipboardMac();
    
    void clearData(const String& type);
    void clearAllData();
    String getData(const String& type, bool& success) const;
    bool setData(const String& type, const String& data);
    
    virtual bool hasData();
    
    // extensions beyond IE's API
    virtual HashSet<String> types() const;
    virtual PassRefPtr<FileList> files() const;

    void setDragImage(CachedImage*, const IntPoint&);
    void setDragImageElement(Node *, const IntPoint&);
    
    virtual DragImageRef createDragImage(IntPoint& dragLoc) const;
#if ENABLE(DRAG_SUPPORT)
    virtual void declareAndWriteDragImage(Element*, const KURL&, const String& title, Frame*);
#endif
    virtual void writeRange(Range*, Frame* frame);
    virtual void writeURL(const KURL&, const String&, Frame* frame);
    virtual void writePlainText(const String&);
    
    // Methods for getting info in Cocoa's type system
    NSImage *dragNSImage(NSPoint&) const; // loc converted from dragLoc, based on whole image size
    NSPasteboard *pasteboard() { return m_pasteboard.get(); }

private:
    ClipboardMac(ClipboardType, NSPasteboard *, ClipboardAccessPolicy, Frame*);

    void setDragImage(CachedImage*, Node*, const IntPoint&);

    RetainPtr<NSPasteboard> m_pasteboard;
    int m_changeCount;
    Frame* m_frame; // used on the source side to generate dragging images
};

}

#endif
