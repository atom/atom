/*
 * Copyright (C) 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
 * Copyright (C) 2008, 2009 Torch Mobile Inc. All rights reserved. (http://www.torchmobile.com/)
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer. 
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution. 
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission. 
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef HistoryController_h
#define HistoryController_h

#include "FrameLoaderTypes.h"
#include "PlatformString.h"
#include "SerializedScriptValue.h"
#include <wtf/Noncopyable.h>
#include <wtf/RefPtr.h>

namespace WebCore {

class Frame;
class HistoryItem;
class SerializedScriptValue;
class StringWithDirection;

class HistoryController {
    WTF_MAKE_NONCOPYABLE(HistoryController);
public:
    enum HistoryUpdateType { UpdateAll, UpdateAllExceptBackForwardList };

    HistoryController(Frame*);
    ~HistoryController();

    void saveScrollPositionAndViewStateToItem(HistoryItem*);
    void restoreScrollPositionAndViewState();

    void updateBackForwardListForFragmentScroll();

    void saveDocumentState();
    void saveDocumentAndScrollState();
    void restoreDocumentState();

    void invalidateCurrentItemCachedPage();

    void updateForBackForwardNavigation();
    void updateForReload();
    void updateForStandardLoad(HistoryUpdateType updateType = UpdateAll);
    void updateForRedirectWithLockedBackForwardList();
    void updateForClientRedirect();
    void updateForCommit();
    void updateForSameDocumentNavigation();
    void updateForFrameLoadCompleted();

    HistoryItem* currentItem() const { return m_currentItem.get(); }
    void setCurrentItem(HistoryItem*);
    void setCurrentItemTitle(const StringWithDirection&);
    bool currentItemShouldBeReplaced() const;

    HistoryItem* previousItem() const { return m_previousItem.get(); }

    HistoryItem* provisionalItem() const { return m_provisionalItem.get(); }
    void setProvisionalItem(HistoryItem*);

    void pushState(PassRefPtr<SerializedScriptValue>, const String& title, const String& url);
    void replaceState(PassRefPtr<SerializedScriptValue>, const String& title, const String& url);

    void setDefersLoading(bool);

private:
    friend class Page;
    bool shouldStopLoadingForHistoryItem(HistoryItem*) const;
    void goToItem(HistoryItem*, FrameLoadType);

    void initializeItem(HistoryItem*);
    PassRefPtr<HistoryItem> createItem();
    PassRefPtr<HistoryItem> createItemTree(Frame* targetFrame, bool clipAtTarget);

    void recursiveSetProvisionalItem(HistoryItem*, HistoryItem*, FrameLoadType);
    void recursiveGoToItem(HistoryItem*, HistoryItem*, FrameLoadType);
    bool isReplaceLoadTypeWithProvisionalItem(FrameLoadType);
    void recursiveUpdateForCommit();
    void recursiveUpdateForSameDocumentNavigation();
    bool itemsAreClones(HistoryItem*, HistoryItem*) const;
    bool currentFramesMatchItem(HistoryItem*) const;
    void updateBackForwardListClippedAtTarget(bool doClip);
    void updateCurrentItem();

    Frame* m_frame;

    RefPtr<HistoryItem> m_currentItem;
    RefPtr<HistoryItem> m_previousItem;
    RefPtr<HistoryItem> m_provisionalItem;

    bool m_frameLoadComplete;

    bool m_defersLoading;
    RefPtr<HistoryItem> m_deferredItem;
    FrameLoadType m_deferredFrameLoadType;
};

} // namespace WebCore

#endif // HistoryController_h
