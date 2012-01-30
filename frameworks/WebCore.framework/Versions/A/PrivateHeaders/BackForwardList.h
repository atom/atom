/*
 * Copyright (C) 2006, 2010 Apple Inc. All rights reserved.
 * Copyright (C) 2008 Torch Mobile Inc. All rights reserved. (http://www.torchmobile.com/)
 * Copyright (C) 2009 Google, Inc. All rights reserved.
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

#ifndef BackForwardList_h
#define BackForwardList_h

#include <wtf/Forward.h>
#include <wtf/RefCounted.h>

namespace WebCore {

class HistoryItem;

// FIXME: Rename this class to BackForwardClient, and rename the
// getter in Page accordingly.
class BackForwardList : public RefCounted<BackForwardList> {
public: 
    virtual ~BackForwardList()
    {
    }

    virtual void addItem(PassRefPtr<HistoryItem>) = 0;

    virtual void goToItem(HistoryItem*) = 0;
        
    virtual HistoryItem* itemAtIndex(int) = 0;
    virtual int backListCount() = 0;
    virtual int forwardListCount() = 0;

    virtual bool isActive() = 0;

    virtual void close() = 0;

    // FIXME: Delete these once all callers are using BackForwardController
    // instead of calling this directly.
    HistoryItem* backItem() { return itemAtIndex(-1); }
    HistoryItem* currentItem() { return itemAtIndex(0); }
    HistoryItem* forwardItem() { return itemAtIndex(1); }
};

} // namespace WebCore

#endif // BackForwardList_h
