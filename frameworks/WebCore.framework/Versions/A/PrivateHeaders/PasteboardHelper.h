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

#ifndef PasteboardHelper_h
#define PasteboardHelper_h

/* FIXME: This is a helper class used to provide access to functionality inside 
 * WebKit.  The required functionality should eventually be migrated to WebCore
 * so that this class can be removed.
 */
#if PLATFORM(MAC)

#import <wtf/Forward.h>

OBJC_CLASS DOMDocumentFragment;

namespace WebCore {

    class Document;
    
    class PasteboardHelper {
    public:
        virtual ~PasteboardHelper() {}
        virtual String urlFromPasteboard(NSPasteboard*, String* title) const = 0;
        virtual String plainTextFromPasteboard(NSPasteboard*) const = 0;
        virtual DOMDocumentFragment* fragmentFromPasteboard(NSPasteboard*) const = 0;
        virtual NSArray* insertablePasteboardTypes() const = 0;
    };
    
}
#endif // PLATFORM(MAC)

#endif // !PasteboardHelper_h
