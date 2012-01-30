/*
 * Copyright (C) 2010 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef BackForwardController_h
#define BackForwardController_h

#include <wtf/Noncopyable.h>
#include <wtf/Forward.h>
#include <wtf/RefPtr.h>

namespace WebCore {

class BackForwardList;
class HistoryItem;
class Page;

class BackForwardController {
    WTF_MAKE_NONCOPYABLE(BackForwardController); WTF_MAKE_FAST_ALLOCATED;
public:
    ~BackForwardController();

    static PassOwnPtr<BackForwardController> create(Page*, PassRefPtr<BackForwardList>);

    BackForwardList* client() const { return m_client.get(); }

    bool canGoBackOrForward(int distance) const;
    void goBackOrForward(int distance);

    bool goBack();
    bool goForward();

    void addItem(PassRefPtr<HistoryItem>);
    void setCurrentItem(HistoryItem*);
        
    int count() const;
    int backCount() const;
    int forwardCount() const;

    HistoryItem* itemAtIndex(int);

    bool isActive();

    void close();

    HistoryItem* backItem() { return itemAtIndex(-1); }
    HistoryItem* currentItem() { return itemAtIndex(0); }
    HistoryItem* forwardItem() { return itemAtIndex(1); }

    void markPagesForFullStyleRecalc();

private:
    BackForwardController(Page*, PassRefPtr<BackForwardList>);

    Page* m_page;
    RefPtr<BackForwardList> m_client;
};

} // namespace WebCore

#endif // BackForwardController_h
