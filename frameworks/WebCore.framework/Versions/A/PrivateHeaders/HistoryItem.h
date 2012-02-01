/*
 * Copyright (C) 2006, 2008, 2011 Apple Inc. All rights reserved.
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

#ifndef HistoryItem_h
#define HistoryItem_h

#include "IntPoint.h"
#include "PlatformString.h"
#include <wtf/HashMap.h>
#include <wtf/OwnPtr.h>
#include <wtf/PassOwnPtr.h>
#include <wtf/RefCounted.h>

#if PLATFORM(MAC)
#import <wtf/RetainPtr.h>
typedef struct objc_object* id;
#endif

#if PLATFORM(QT)
#include <QVariant>
#include <QByteArray>
#include <QDataStream>
#endif

namespace WebCore {

class CachedPage;
class Document;
class FormData;
class HistoryItem;
class Image;
class KURL;
class ResourceRequest;
class SerializedScriptValue;

typedef Vector<RefPtr<HistoryItem> > HistoryItemVector;

extern void (*notifyHistoryItemChanged)(HistoryItem*);

enum VisitCountBehavior {
    IncreaseVisitCount,
    DoNotIncreaseVisitCount
};

class HistoryItem : public RefCounted<HistoryItem> {
    friend class PageCache;

public: 
    static PassRefPtr<HistoryItem> create() { return adoptRef(new HistoryItem); }
    static PassRefPtr<HistoryItem> create(const String& urlString, const String& title, double lastVisited)
    {
        return adoptRef(new HistoryItem(urlString, title, lastVisited));
    }
    static PassRefPtr<HistoryItem> create(const String& urlString, const String& title, const String& alternateTitle, double lastVisited)
    {
        return adoptRef(new HistoryItem(urlString, title, alternateTitle, lastVisited));
    }
    static PassRefPtr<HistoryItem> create(const KURL& url, const String& target, const String& parent, const String& title)
    {
        return adoptRef(new HistoryItem(url, target, parent, title));
    }
    
    ~HistoryItem();

    PassRefPtr<HistoryItem> copy() const;

    // Resets the HistoryItem to its initial state, as returned by create().
    void reset();
    
    void encodeBackForwardTree(Encoder&) const;
    static PassRefPtr<HistoryItem> decodeBackForwardTree(const String& urlString, const String& title, const String& originalURLString, Decoder&);

    const String& originalURLString() const;
    const String& urlString() const;
    const String& title() const;
    
    bool isInPageCache() const { return m_cachedPage; }
    
    double lastVisitedTime() const;
    
    void setAlternateTitle(const String& alternateTitle);
    const String& alternateTitle() const;
    
    const String& parent() const;
    KURL url() const;
    KURL originalURL() const;
    const String& referrer() const;
    const String& target() const;
    bool isTargetItem() const;
    
    FormData* formData();
    String formContentType() const;
    
    int visitCount() const;
    bool lastVisitWasFailure() const { return m_lastVisitWasFailure; }
    bool lastVisitWasHTTPNonGet() const { return m_lastVisitWasHTTPNonGet; }

    void mergeAutoCompleteHints(HistoryItem* otherItem);
    
    const IntPoint& scrollPoint() const;
    void setScrollPoint(const IntPoint&);
    void clearScrollPoint();
    
    float pageScaleFactor() const;
    void setPageScaleFactor(float);
    
    const Vector<String>& documentState() const;
    void setDocumentState(const Vector<String>&);
    void clearDocumentState();

    void setURL(const KURL&);
    void setURLString(const String&);
    void setOriginalURLString(const String&);
    void setReferrer(const String&);
    void setTarget(const String&);
    void setParent(const String&);
    void setTitle(const String&);
    void setIsTargetItem(bool);
    
    void setStateObject(PassRefPtr<SerializedScriptValue> object);
    SerializedScriptValue* stateObject() const { return m_stateObject.get(); }

    void setItemSequenceNumber(long long number) { m_itemSequenceNumber = number; }
    long long itemSequenceNumber() const { return m_itemSequenceNumber; }

    void setDocumentSequenceNumber(long long number) { m_documentSequenceNumber = number; }
    long long documentSequenceNumber() const { return m_documentSequenceNumber; }

    void setFormInfoFromRequest(const ResourceRequest&);
    void setFormData(PassRefPtr<FormData>);
    void setFormContentType(const String&);

    void recordInitialVisit();

    void setVisitCount(int);
    void setLastVisitWasFailure(bool wasFailure) { m_lastVisitWasFailure = wasFailure; }
    void setLastVisitWasHTTPNonGet(bool wasNotGet) { m_lastVisitWasHTTPNonGet = wasNotGet; }

    void addChildItem(PassRefPtr<HistoryItem>);
    void setChildItem(PassRefPtr<HistoryItem>);
    HistoryItem* childItemWithTarget(const String&) const;
    HistoryItem* childItemWithDocumentSequenceNumber(long long number) const;
    HistoryItem* targetItem();
    const HistoryItemVector& children() const;
    bool hasChildren() const;
    void clearChildren();
    
    bool shouldDoSameDocumentNavigationTo(HistoryItem* otherItem) const;
    bool hasSameFrames(HistoryItem* otherItem) const;

    // This should not be called directly for HistoryItems that are already included
    // in GlobalHistory. The WebKit api for this is to use -[WebHistory setLastVisitedTimeInterval:forItem:] instead.
    void setLastVisitedTime(double);
    void visited(const String& title, double time, VisitCountBehavior);

    void addRedirectURL(const String&);
    Vector<String>* redirectURLs() const;
    void setRedirectURLs(PassOwnPtr<Vector<String> >);

    bool isCurrentDocument(Document*) const;
    
#if PLATFORM(MAC)
    id viewState() const;
    void setViewState(id);
    
    // Transient properties may be of any ObjC type.  They are intended to be used to store state per back/forward list entry.
    // The properties will not be persisted; when the history item is removed, the properties will be lost.
    id getTransientProperty(const String&) const;
    void setTransientProperty(const String&, id);
#endif

#if PLATFORM(QT)
    QVariant userData() const { return m_userData; }
    void setUserData(const QVariant& userData) { m_userData = userData; }

    bool restoreState(QDataStream& buffer, int version);
    QDataStream& saveState(QDataStream& out, int version) const;
#endif

#ifndef NDEBUG
    int showTree() const;
    int showTreeWithIndent(unsigned indentLevel) const;
#endif

    void adoptVisitCounts(Vector<int>& dailyCounts, Vector<int>& weeklyCounts);
    const Vector<int>& dailyVisitCounts() const { return m_dailyVisitCounts; }
    const Vector<int>& weeklyVisitCounts() const { return m_weeklyVisitCounts; }

    void markForFullStyleRecalc();

private:
    HistoryItem();
    HistoryItem(const String& urlString, const String& title, double lastVisited);
    HistoryItem(const String& urlString, const String& title, const String& alternateTitle, double lastVisited);
    HistoryItem(const KURL& url, const String& frameName, const String& parent, const String& title);

    HistoryItem(const HistoryItem&);

    void padDailyCountsForNewVisit(double time);
    void collapseDailyVisitsToWeekly();
    void recordVisitAtTime(double, VisitCountBehavior = IncreaseVisitCount);
    
    bool hasSameDocumentTree(HistoryItem* otherItem) const;

    HistoryItem* findTargetItem();

    void encodeBackForwardTreeNode(Encoder&) const;

    /* When adding new member variables to this class, please notify the Qt team.
     * qt/HistoryItemQt.cpp contains code to serialize history items.
     */

    String m_urlString;
    String m_originalURLString;
    String m_referrer;
    String m_target;
    String m_parent;
    String m_title;
    String m_displayTitle;
    
    double m_lastVisitedTime;
    bool m_lastVisitWasHTTPNonGet;

    IntPoint m_scrollPoint;
    float m_pageScaleFactor;
    Vector<String> m_documentState;
    
    HistoryItemVector m_children;
    
    bool m_lastVisitWasFailure;
    bool m_isTargetItem;
    int m_visitCount;
    Vector<int> m_dailyVisitCounts;
    Vector<int> m_weeklyVisitCounts;

    OwnPtr<Vector<String> > m_redirectURLs;

    // If two HistoryItems have the same item sequence number, then they are
    // clones of one another.  Traversing history from one such HistoryItem to
    // another is a no-op.  HistoryItem clones are created for parent and
    // sibling frames when only a subframe navigates.
    int64_t m_itemSequenceNumber;

    // If two HistoryItems have the same document sequence number, then they
    // refer to the same instance of a document.  Traversing history from one
    // such HistoryItem to another preserves the document.
    int64_t m_documentSequenceNumber;

    // Support for HTML5 History
    RefPtr<SerializedScriptValue> m_stateObject;
    
    // info used to repost form data
    RefPtr<FormData> m_formData;
    String m_formContentType;

    // PageCache controls these fields.
    HistoryItem* m_next;
    HistoryItem* m_prev;
    RefPtr<CachedPage> m_cachedPage;
    
#if PLATFORM(MAC)
    RetainPtr<id> m_viewState;
    OwnPtr<HashMap<String, RetainPtr<id> > > m_transientProperties;
#endif

#if PLATFORM(QT)
    QVariant m_userData;
#endif

}; //class HistoryItem

} //namespace WebCore

#ifndef NDEBUG
// Outside the WebCore namespace for ease of invocation from gdb.
extern "C" int showTree(const WebCore::HistoryItem*);
#endif

#endif // HISTORYITEM_H
