/*
 * Copyright (C) 2006, 2007, 2008, 2009, 2011 Apple Inc. All rights reserved.
 * Copyright (C) 2008, 2009 Torch Mobile Inc. All rights reserved. (http://www.torchmobile.com/)
 * Copyright (C) Research In Motion Limited 2009. All rights reserved.
 * Copyright (C) 2011 Google Inc. All rights reserved.
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

#ifndef FrameLoader_h
#define FrameLoader_h

#include "CachePolicy.h"
#include "FrameLoaderStateMachine.h"
#include "FrameLoaderTypes.h"
#include "HistoryController.h"
#include "IconController.h"
#include "IconURL.h"
#include "PolicyChecker.h"
#include "ResourceHandle.h"
#include "ResourceLoadNotifier.h"
#include "SecurityContext.h"
#include "SubframeLoader.h"
#include "Timer.h"
#include <wtf/Forward.h>
#include <wtf/HashSet.h>

namespace WebCore {

class Archive;
class CachedFrameBase;
class CachedPage;
class CachedResource;
class Chrome;
class DOMWrapperWorld;
class DocumentLoader;
class Event;
class FormState;
class FormSubmission;
class FrameLoaderClient;
class FrameNetworkingContext;
class NavigationAction;
class NetworkingContext;
class Page;
class ResourceError;
class ResourceRequest;
class ResourceResponse;
class SecurityOrigin;
class SerializedScriptValue;
class StringWithDirection;
class SubstituteData;

struct FrameLoadRequest;
struct WindowFeatures;

bool isBackForwardLoadType(FrameLoadType);

class FrameLoader {
    WTF_MAKE_NONCOPYABLE(FrameLoader);
public:
    FrameLoader(Frame*, FrameLoaderClient*);
    ~FrameLoader();

    void init();

    Frame* frame() const { return m_frame; }

    PolicyChecker* policyChecker() const { return &m_policyChecker; }
    HistoryController* history() const { return &m_history; }
    ResourceLoadNotifier* notifier() const { return &m_notifer; }
    SubframeLoader* subframeLoader() const { return &m_subframeLoader; }
    IconController* icon() const { return &m_icon; }

    void prepareForHistoryNavigation();
    void prepareForLoadStart();
    void setupForReplace();

    // FIXME: These are all functions which start loads. We have too many.
    void loadURLIntoChildFrame(const KURL&, const String& referer, Frame*);
    void loadFrameRequest(const FrameLoadRequest&, bool lockHistory, bool lockBackForwardList,  // Called by submitForm, calls loadPostRequest and loadURL.
        PassRefPtr<Event>, PassRefPtr<FormState>, ShouldSendReferrer);

    void load(const ResourceRequest&, bool lockHistory);                                        // Called by WebFrame, calls load(ResourceRequest, SubstituteData).
    void load(const ResourceRequest&, const SubstituteData&, bool lockHistory);                 // Called both by WebFrame and internally, calls load(DocumentLoader*).
    void load(const ResourceRequest&, const String& frameName, bool lockHistory);               // Called by WebPluginController.
#if ENABLE(WEB_ARCHIVE) || ENABLE(MHTML)
    void loadArchive(PassRefPtr<Archive>);
#endif
    unsigned long loadResourceSynchronously(const ResourceRequest&, StoredCredentials, ResourceError&, ResourceResponse&, Vector<char>& data);

    void changeLocation(SecurityOrigin*, const KURL&, const String& referrer, bool lockHistory = true, bool lockBackForwardList = true, bool refresh = false);
    void urlSelected(const KURL&, const String& target, PassRefPtr<Event>, bool lockHistory, bool lockBackForwardList, ShouldSendReferrer);
    void submitForm(PassRefPtr<FormSubmission>);

    void reload(bool endToEndReload = false);
    void reloadWithOverrideEncoding(const String& overrideEncoding);

    void open(CachedFrameBase&);
    void loadItem(HistoryItem*, FrameLoadType);

    static void reportLocalLoadFailed(Frame*, const String& url);

    // FIXME: These are all functions which stop loads. We have too many.
    void stopAllLoaders(ClearProvisionalItemPolicy = ShouldClearProvisionalItem);
    void stopForUserCancel(bool deferCheckLoadComplete = false);
    void stop();
    void stopLoading(UnloadEventPolicy);
    bool closeURL();
    void cancelAndClear();
    void clear(bool clearWindowProperties = true, bool clearScriptObjects = true, bool clearFrameView = true);

    bool isLoadingMainResource() const { return m_isLoadingMainResource; }
    bool isLoading() const;
    bool frameHasLoaded() const;
    void transferLoadingResourcesFromPage(Page*);
    void dispatchTransferLoadingResourceFromPage(ResourceLoader*, const ResourceRequest&, Page*);

    int numPendingOrLoadingRequests(bool recurse) const;
    String referrer() const;
    String outgoingReferrer() const;
    String outgoingOrigin() const;

    DocumentLoader* activeDocumentLoader() const;
    DocumentLoader* documentLoader() const { return m_documentLoader.get(); }
    DocumentLoader* policyDocumentLoader() const { return m_policyDocumentLoader.get(); }
    DocumentLoader* provisionalDocumentLoader() const { return m_provisionalDocumentLoader.get(); }
    FrameState state() const { return m_state; }
    static double timeOfLastCompletedLoad();

    const ResourceRequest& originalRequest() const;
    const ResourceRequest& initialRequest() const;
    void receivedMainResourceError(const ResourceError&, bool isComplete);

    bool willLoadMediaElementURL(KURL&);

    void handleFallbackContent();

    void finishedLoading();

    ResourceError cancelledError(const ResourceRequest&) const;

    bool isHostedByObjectElement() const;
    bool isLoadingMainFrame() const;

    void finishedLoadingDocument(DocumentLoader*);
    bool isReplacing() const;
    void setReplacing();
    void mainReceivedCompleteError(DocumentLoader*, const ResourceError&);
    bool subframeIsLoading() const;
    void willChangeTitle(DocumentLoader*);
    void didChangeTitle(DocumentLoader*);
    void didChangeIcons(IconType);

    FrameLoadType loadType() const;

    CachePolicy subresourceCachePolicy() const;

    void didFirstLayout();
    void didFirstVisuallyNonEmptyLayout();

    void loadedResourceFromMemoryCache(CachedResource*);
    void tellClientAboutPastMemoryCacheLoads();

    void checkLoadComplete();
    void detachFromParent();
    void detachViewsAndDocumentLoader();

    void addExtraFieldsToSubresourceRequest(ResourceRequest&);
    void addExtraFieldsToMainResourceRequest(ResourceRequest&);
    
    static void addHTTPOriginIfNeeded(ResourceRequest&, const String& origin);

    FrameLoaderClient* client() const { return m_client; }

    void setDefersLoading(bool);

    void didExplicitOpen();

    // Callbacks from DocumentWriter
    void didBeginDocument(bool dispatchWindowObjectAvailable);
    void didEndDocument();
    void willSetEncoding();

    void handledOnloadEvents();
    String userAgent(const KURL&) const;

    void dispatchDidClearWindowObjectInWorld(DOMWrapperWorld*);
    void dispatchDidClearWindowObjectsInAllWorlds();
    void dispatchDocumentElementAvailable();

    // The following sandbox flags will be forced, regardless of changes to
    // the sandbox attribute of any parent frames.
    void forceSandboxFlags(SandboxFlags flags) { m_forcedSandboxFlags |= flags; }
    SandboxFlags effectiveSandboxFlags() const;

    // Mixed content related functions.
    static bool isMixedContent(SecurityOrigin* context, const KURL&);
    bool checkIfDisplayInsecureContent(SecurityOrigin* context, const KURL&);
    bool checkIfRunInsecureContent(SecurityOrigin* context, const KURL&);

    Frame* opener();
    void setOpener(Frame*);

    void resetMultipleFormSubmissionProtection();

    void checkCallImplicitClose();

    void frameDetached();

    void setOutgoingReferrer(const KURL&);

    void loadDone();
    void finishedParsing();
    void checkCompleted();

    void checkDidPerformFirstNavigation();

    bool isComplete() const;

    void setTitle(const StringWithDirection&);

    void commitProvisionalLoad();

    FrameLoaderStateMachine* stateMachine() const { return &m_stateMachine; }

    bool shouldAllowNavigation(Frame* targetFrame) const;
    Frame* findFrameForNavigation(const AtomicString& name);

    void applyUserAgent(ResourceRequest&);

    bool shouldInterruptLoadForXFrameOptions(const String&, const KURL&);

    void completed();
    bool allAncestorsAreComplete() const; // including this
    void clientRedirected(const KURL&, double delay, double fireDate, bool lockBackForwardList);
    void clientRedirectCancelledOrFinished(bool cancelWithLoadInProgress);

    // FIXME: This is public because this asynchronous callback from the FrameLoaderClient
    // uses the policy machinery (and therefore is called via the PolicyChecker).  Once we
    // introduce a proper callback type for this function, we should make it private again.
    void continueLoadAfterWillSubmitForm();

    void setOriginalURLForDownloadRequest(ResourceRequest&);

    bool suppressOpenerInNewFrame() const { return m_suppressOpenerInNewFrame; }

    static ObjectContentType defaultObjectContentType(const KURL&, const String& mimeType, bool shouldPreferPlugInsForImages);

    bool quickRedirectComing() const { return m_quickRedirectComing; }

    bool shouldClose();
    
    void started();

    enum PageDismissalType {
        NoDismissal = 0,
        BeforeUnloadDismissal = 1,
        PageHideDismissal = 2,
        UnloadDismissal = 3
    };
    PageDismissalType pageDismissalEventBeingDispatched() const { return m_pageDismissalEventBeingDispatched; }

    NetworkingContext* networkingContext() const;

#if ENABLE(WEB_ARCHIVE) || ENABLE(MHTML)
    Archive* archive() const { return m_archive.get(); }
#endif

private:
    bool allChildrenAreComplete() const; // immediate children, not all descendants

    void checkTimerFired(Timer<FrameLoader>*);
    
    void loadSameDocumentItem(HistoryItem*);
    void loadDifferentDocumentItem(HistoryItem*, FrameLoadType);
    
    void loadProvisionalItemFromCachedPage();

    void receivedFirstData();

    void updateFirstPartyForCookies();
    void setFirstPartyForCookies(const KURL&);
    
    void addExtraFieldsToRequest(ResourceRequest&, FrameLoadType, bool isMainResource);

    void clearProvisionalLoad();
    void transitionToCommitted(PassRefPtr<CachedPage>);
    void frameLoadCompleted();

    static void callContinueLoadAfterNavigationPolicy(void*, const ResourceRequest&, PassRefPtr<FormState>, bool shouldContinue);
    static void callContinueLoadAfterNewWindowPolicy(void*, const ResourceRequest&, PassRefPtr<FormState>, const String& frameName, const NavigationAction&, bool shouldContinue);
    static void callContinueFragmentScrollAfterNavigationPolicy(void*, const ResourceRequest&, PassRefPtr<FormState>, bool shouldContinue);
    
    bool fireBeforeUnloadEvent(Chrome*);

    void continueLoadAfterNavigationPolicy(const ResourceRequest&, PassRefPtr<FormState>, bool shouldContinue);
    void continueLoadAfterNewWindowPolicy(const ResourceRequest&, PassRefPtr<FormState>, const String& frameName, const NavigationAction&, bool shouldContinue);
    void continueFragmentScrollAfterNavigationPolicy(const ResourceRequest&, bool shouldContinue);

    bool shouldScrollToAnchor(bool isFormSubmission, const String& httpMethod, FrameLoadType, const KURL&);

    void checkLoadCompleteForThisFrame();

    void setDocumentLoader(DocumentLoader*);
    void setPolicyDocumentLoader(DocumentLoader*);
    void setProvisionalDocumentLoader(DocumentLoader*);

    void setState(FrameState);

    void closeOldDataSources();
    void prepareForCachedPageRestore();

    bool shouldReloadToHandleUnreachableURL(DocumentLoader*);

    void dispatchDidCommitLoad();

    void urlSelected(const FrameLoadRequest&, PassRefPtr<Event>, bool lockHistory, bool lockBackForwardList, ShouldSendReferrer, ShouldReplaceDocumentIfJavaScriptURL);

    void loadWithDocumentLoader(DocumentLoader*, FrameLoadType, PassRefPtr<FormState>); // Calls continueLoadAfterNavigationPolicy
    void load(DocumentLoader*);                                                         // Calls loadWithDocumentLoader   

    void loadWithNavigationAction(const ResourceRequest&, const NavigationAction&,      // Calls loadWithDocumentLoader
        bool lockHistory, FrameLoadType, PassRefPtr<FormState>);

    void loadPostRequest(const ResourceRequest&, const String& referrer,                // Called by loadFrameRequest, calls loadWithNavigationAction
        const String& frameName, bool lockHistory, FrameLoadType, PassRefPtr<Event>, PassRefPtr<FormState>);
    void loadURL(const KURL&, const String& referrer, const String& frameName,          // Called by loadFrameRequest, calls loadWithNavigationAction or dispatches to navigation policy delegate
        bool lockHistory, FrameLoadType, PassRefPtr<Event>, PassRefPtr<FormState>);                                                         

    bool shouldReload(const KURL& currentURL, const KURL& destinationURL);

    void requestFromDelegate(ResourceRequest&, unsigned long& identifier, ResourceError&);

    void detachChildren();
    void closeAndRemoveChild(Frame*);

    void loadInSameDocument(const KURL&, SerializedScriptValue* stateObject, bool isNewNavigation);

    void provisionalLoadStarted();

    bool didOpenURL();

    void scheduleCheckCompleted();
    void scheduleCheckLoadComplete();
    void startCheckCompleteTimer();

    bool shouldTreatURLAsSameAsCurrent(const KURL&) const;

    Frame* m_frame;
    FrameLoaderClient* m_client;

    mutable PolicyChecker m_policyChecker;
    mutable HistoryController m_history;
    mutable ResourceLoadNotifier m_notifer;
    mutable SubframeLoader m_subframeLoader;
    mutable FrameLoaderStateMachine m_stateMachine;
    mutable IconController m_icon;

    FrameState m_state;
    FrameLoadType m_loadType;

    // Document loaders for the three phases of frame loading. Note that while 
    // a new request is being loaded, the old document loader may still be referenced.
    // E.g. while a new request is in the "policy" state, the old document loader may
    // be consulted in particular as it makes sense to imply certain settings on the new loader.
    RefPtr<DocumentLoader> m_documentLoader;
    RefPtr<DocumentLoader> m_provisionalDocumentLoader;
    RefPtr<DocumentLoader> m_policyDocumentLoader;

    bool m_delegateIsHandlingProvisionalLoadError;

    bool m_quickRedirectComing;
    bool m_sentRedirectNotification;
    bool m_inStopAllLoaders;

    String m_outgoingReferrer;

    bool m_isExecutingJavaScriptFormAction;

    bool m_didCallImplicitClose;
    bool m_wasUnloadEventEmitted;
    PageDismissalType m_pageDismissalEventBeingDispatched;
    bool m_isComplete;
    bool m_isLoadingMainResource;

    RefPtr<SerializedScriptValue> m_pendingStateObject;

    bool m_hasReceivedFirstData;

    bool m_needsClear;

    KURL m_submittedFormURL;

    Timer<FrameLoader> m_checkTimer;
    bool m_shouldCallCheckCompleted;
    bool m_shouldCallCheckLoadComplete;

    Frame* m_opener;
    HashSet<Frame*> m_openedFrames;

    bool m_didPerformFirstNavigation;
    bool m_loadingFromCachedPage;
    bool m_suppressOpenerInNewFrame;

    SandboxFlags m_forcedSandboxFlags;

    RefPtr<FrameNetworkingContext> m_networkingContext;

#if ENABLE(WEB_ARCHIVE) || ENABLE(MHTML)
    RefPtr<Archive> m_archive;
#endif

    KURL m_previousUrl;
};

// This function is called by createWindow() in JSDOMWindowBase.cpp, for example, for
// modal dialog creation.  The lookupFrame is for looking up the frame name in case
// the frame name references a frame different from the openerFrame, e.g. when it is
// "_self" or "_parent".
//
// FIXME: Consider making this function part of an appropriate class (not FrameLoader)
// and moving it to a more appropriate location.
Frame* createWindow(Frame* openerFrame, Frame* lookupFrame, const FrameLoadRequest&, const WindowFeatures&, bool& created);

} // namespace WebCore

#endif // FrameLoader_h
