/*
 * Copyright (C) 2006, 2007 Apple Inc. All rights reserved.
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

#ifndef ContextMenuController_h
#define ContextMenuController_h

#include "HitTestResult.h"
#include <wtf/Noncopyable.h>
#include <wtf/OwnPtr.h>
#include <wtf/PassRefPtr.h>
#include <wtf/RefPtr.h>

namespace WebCore {

    class ContextMenu;
    class ContextMenuClient;
    class ContextMenuItem;
    class ContextMenuProvider;
    class Event;
    class Page;

    class ContextMenuController {
        WTF_MAKE_NONCOPYABLE(ContextMenuController); WTF_MAKE_FAST_ALLOCATED;
    public:
        ~ContextMenuController();

        static PassOwnPtr<ContextMenuController> create(Page*, ContextMenuClient*);

        ContextMenuClient* client() const { return m_client; }

        ContextMenu* contextMenu() const { return m_contextMenu.get(); }
        void clearContextMenu();

        void handleContextMenuEvent(Event*);
        void showContextMenu(Event*, PassRefPtr<ContextMenuProvider>);

        void populate();
        void contextMenuItemSelected(ContextMenuItem*);
        void addInspectElementItem();

        void checkOrEnableIfNeeded(ContextMenuItem&) const;

        void setHitTestResult(const HitTestResult& result) { m_hitTestResult = result; }
        const HitTestResult& hitTestResult() { return m_hitTestResult; }

    private:
        ContextMenuController(Page*, ContextMenuClient*);

        PassOwnPtr<ContextMenu> createContextMenu(Event*);
        void showContextMenu(Event*);
        
        void appendItem(ContextMenuItem&, ContextMenu* parentMenu);

        void createAndAppendFontSubMenu(ContextMenuItem&);
        void createAndAppendSpellingAndGrammarSubMenu(ContextMenuItem&);
        void createAndAppendSpellingSubMenu(ContextMenuItem&);
        void createAndAppendSpeechSubMenu(ContextMenuItem& );
        void createAndAppendWritingDirectionSubMenu(ContextMenuItem&);
        void createAndAppendTextDirectionSubMenu(ContextMenuItem&);
        void createAndAppendSubstitutionsSubMenu(ContextMenuItem&);
        void createAndAppendTransformationsSubMenu(ContextMenuItem&);

        Page* m_page;
        ContextMenuClient* m_client;
        OwnPtr<ContextMenu> m_contextMenu;
        RefPtr<ContextMenuProvider> m_menuProvider;
        HitTestResult m_hitTestResult;
    };

}

#endif
