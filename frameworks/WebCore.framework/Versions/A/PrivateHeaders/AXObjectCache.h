/*
 * Copyright (C) 2003, 2006, 2007, 2008, 2009, 2010, 2011 Apple Inc. All rights reserved.
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

#ifndef AXObjectCache_h
#define AXObjectCache_h

#include "AccessibilityObject.h"
#include "Timer.h"
#include <limits.h>
#include <wtf/Forward.h>
#include <wtf/HashMap.h>
#include <wtf/HashSet.h>
#include <wtf/RefPtr.h>

namespace WebCore {

class Document;
class HTMLAreaElement;
class Node;
class Page;
class RenderObject;
class ScrollView;
class VisiblePosition;
class Widget;

struct TextMarkerData {
    AXID axID;
    Node* node;
    int offset;
    EAffinity affinity;
};

enum PostType { PostSynchronously, PostAsynchronously };

class AXObjectCache {
    WTF_MAKE_NONCOPYABLE(AXObjectCache); WTF_MAKE_FAST_ALLOCATED;
public:
    AXObjectCache(const Document*);
    ~AXObjectCache();

    static AccessibilityObject* focusedUIElementForPage(const Page*);

    // Returns the root object for the entire document.
    AccessibilityObject* rootObject();
    // Returns the root object for a specific frame.
    AccessibilityObject* rootObjectForFrame(Frame*);
    
    // For AX objects with elements that back them.
    AccessibilityObject* getOrCreate(RenderObject*);
    AccessibilityObject* getOrCreate(Widget*);

    // used for objects without backing elements
    AccessibilityObject* getOrCreate(AccessibilityRole);
    
    // will only return the AccessibilityObject if it already exists
    AccessibilityObject* get(RenderObject*);
    AccessibilityObject* get(Widget*);
    
    void remove(RenderObject*);
    void remove(Widget*);
    void remove(AXID);

    void detachWrapper(AccessibilityObject*);
    void attachWrapper(AccessibilityObject*);
    void childrenChanged(RenderObject*);
    void checkedStateChanged(RenderObject*);
    void selectedChildrenChanged(RenderObject*);
    // Called by a node when text or a text equivalent (e.g. alt) attribute is changed.
    void contentChanged(RenderObject*);
    
    void handleActiveDescendantChanged(RenderObject*);
    void handleAriaRoleChanged(RenderObject*);
    void handleFocusedUIElementChanged(RenderObject* oldFocusedRenderer, RenderObject* newFocusedRenderer);
    void handleScrolledToAnchor(const Node* anchorNode);
    void handleAriaExpandedChange(RenderObject*);
    void handleScrollbarUpdate(ScrollView*);
    
    static void enableAccessibility() { gAccessibilityEnabled = true; }
    // Enhanced user interface accessibility can be toggled by the assistive technology.
    static void setEnhancedUserInterfaceAccessibility(bool flag) { gAccessibilityEnhancedUserInterfaceEnabled = flag; }
    
    static bool accessibilityEnabled() { return gAccessibilityEnabled; }
    static bool accessibilityEnhancedUserInterfaceEnabled() { return gAccessibilityEnhancedUserInterfaceEnabled; }

    void removeAXID(AccessibilityObject*);
    bool isIDinUse(AXID id) const { return m_idsInUse.contains(id); }

    Element* rootAXEditableElement(Node*);
    const Element* rootAXEditableElement(const Node*);
    bool nodeIsTextControl(const Node*);

    AXID platformGenerateAXID() const;
    AccessibilityObject* objectFromAXID(AXID id) const { return m_objects.get(id).get(); }

    // This is a weak reference cache for knowing if Nodes used by TextMarkers are valid.
    void setNodeInUse(Node* n) { m_textMarkerNodes.add(n); }
    void removeNodeForUse(Node* n) { m_textMarkerNodes.remove(n); }
    bool isNodeInUse(Node* n) { return m_textMarkerNodes.contains(n); }
    
    // Text marker utilities.
    void textMarkerDataForVisiblePosition(TextMarkerData&, const VisiblePosition&);
    VisiblePosition visiblePositionForTextMarkerData(TextMarkerData&);

    enum AXNotification {
        AXActiveDescendantChanged,
        AXAutocorrectionOccured,
        AXCheckedStateChanged,
        AXChildrenChanged,
        AXFocusedUIElementChanged,
        AXLayoutComplete,
        AXLoadComplete,
        AXSelectedChildrenChanged,
        AXSelectedTextChanged,
        AXValueChanged,
        AXScrolledToAnchor,
        AXLiveRegionChanged,
        AXMenuListItemSelected,
        AXMenuListValueChanged,
        AXRowCountChanged,
        AXRowCollapsed,
        AXRowExpanded,
        AXInvalidStatusChanged,
    };

    void postNotification(RenderObject*, AXNotification, bool postToElement, PostType = PostAsynchronously);
    void postNotification(AccessibilityObject*, Document*, AXNotification, bool postToElement, PostType = PostAsynchronously);

    enum AXTextChange {
        AXTextInserted,
        AXTextDeleted,
    };

    void nodeTextChangeNotification(RenderObject*, AXTextChange, unsigned offset, const String&);

    enum AXLoadingEvent {
        AXLoadingStarted,
        AXLoadingReloaded,
        AXLoadingFailed,
        AXLoadingFinished
    };

    void frameLoadingEventNotification(Frame*, AXLoadingEvent);

    bool nodeHasRole(Node*, const AtomicString& role);

protected:
    void postPlatformNotification(AccessibilityObject*, AXNotification);
    void nodeTextChangePlatformNotification(AccessibilityObject*, AXTextChange, unsigned offset, const String&);
    void frameLoadingEventPlatformNotification(AccessibilityObject*, AXLoadingEvent);

private:
    Document* m_document;
    HashMap<AXID, RefPtr<AccessibilityObject> > m_objects;
    HashMap<RenderObject*, AXID> m_renderObjectMapping;
    HashMap<Widget*, AXID> m_widgetObjectMapping;
    HashSet<Node*> m_textMarkerNodes;
    static bool gAccessibilityEnabled;
    static bool gAccessibilityEnhancedUserInterfaceEnabled;
    
    HashSet<AXID> m_idsInUse;
    
    Timer<AXObjectCache> m_notificationPostTimer;
    Vector<pair<RefPtr<AccessibilityObject>, AXNotification> > m_notificationsToPost;
    void notificationPostTimerFired(Timer<AXObjectCache>*);
    
    static AccessibilityObject* focusedImageMapUIElement(HTMLAreaElement*);
    
    AXID getAXID(AccessibilityObject*);
};

bool nodeHasRole(Node*, const String& role);

#if !HAVE(ACCESSIBILITY)
inline void AXObjectCache::handleActiveDescendantChanged(RenderObject*) { }
inline void AXObjectCache::handleAriaRoleChanged(RenderObject*) { }
inline void AXObjectCache::detachWrapper(AccessibilityObject*) { }
inline void AXObjectCache::attachWrapper(AccessibilityObject*) { }
inline void AXObjectCache::checkedStateChanged(RenderObject*) { }
inline void AXObjectCache::selectedChildrenChanged(RenderObject*) { }
inline void AXObjectCache::postNotification(RenderObject*, AXNotification, bool postToElement, PostType) { }
inline void AXObjectCache::postNotification(AccessibilityObject*, Document*, AXNotification, bool postToElement, PostType) { }
inline void AXObjectCache::postPlatformNotification(AccessibilityObject*, AXNotification) { }
inline void AXObjectCache::nodeTextChangeNotification(RenderObject*, AXTextChange, unsigned, const String&) { }
inline void AXObjectCache::nodeTextChangePlatformNotification(AccessibilityObject*, AXTextChange, unsigned, const String&) { }
inline void AXObjectCache::frameLoadingEventNotification(Frame*, AXLoadingEvent) { }
inline void AXObjectCache::frameLoadingEventPlatformNotification(AccessibilityObject*, AXLoadingEvent) { }
inline void AXObjectCache::handleFocusedUIElementChanged(RenderObject*, RenderObject*) { }
inline void AXObjectCache::handleScrolledToAnchor(const Node*) { }
inline void AXObjectCache::contentChanged(RenderObject*) { }
inline void AXObjectCache::handleAriaExpandedChange(RenderObject*) { }
inline void AXObjectCache::handleScrollbarUpdate(ScrollView*) { }
#endif

}

#endif
