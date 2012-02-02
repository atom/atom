/*
 * Copyright (C) 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
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

#ifndef DocumentLoader_h
#define DocumentLoader_h

#include "DocumentLoadTiming.h"
#include "DocumentWriter.h"
#include "IconDatabaseBase.h"
#include "NavigationAction.h"
#include "ResourceError.h"
#include "ResourceRequest.h"
#include "ResourceResponse.h"
#include "StringWithDirection.h"
#include "SubstituteData.h"
#include "Timer.h"
#include <wtf/HashSet.h>
#include <wtf/RefPtr.h>
#include <wtf/Vector.h>

namespace WebCore {

    class ApplicationCacheHost;
#if ENABLE(WEB_ARCHIVE) || ENABLE(MHTML)
    class Archive;
#endif
    class ArchiveResource;
    class ArchiveResourceCollection;
    class Frame;
    class FrameLoader;
    class MainResourceLoader;
    class Page;
    class ResourceLoader;
    class SchedulePair;
    class SharedBuffer;
    class SubstituteResource;

    typedef HashSet<RefPtr<ResourceLoader> > ResourceLoaderSet;
    typedef Vector<ResourceResponse> ResponseVector;

    class DocumentLoader : public RefCounted<DocumentLoader> {
    public:
        static PassRefPtr<DocumentLoader> create(const ResourceRequest& request, const SubstituteData& data)
        {
            return adoptRef(new DocumentLoader(request, data));
        }
        virtual ~DocumentLoader();

        void setFrame(Frame*);
        Frame* frame() const { return m_frame; }

        virtual void attachToFrame();
        virtual void detachFromFrame();

        FrameLoader* frameLoader() const;
        MainResourceLoader* mainResourceLoader() const { return m_mainResourceLoader.get(); }
        PassRefPtr<SharedBuffer> mainResourceData() const;
        
        DocumentWriter* writer() const { return &m_writer; }

        const ResourceRequest& originalRequest() const;
        const ResourceRequest& originalRequestCopy() const;

        const ResourceRequest& request() const;
        ResourceRequest& request();
        void setRequest(const ResourceRequest&);

        const SubstituteData& substituteData() const { return m_substituteData; }

        // FIXME: This is the same as requestURL(). We should remove one of them.
        const KURL& url() const;
        const KURL& unreachableURL() const;

        // The URL of the document resulting from this DocumentLoader.
        KURL documentURL() const;

        const KURL& originalURL() const;
        const KURL& requestURL() const;
        const KURL& responseURL() const;
        const String& responseMIMEType() const;

        void replaceRequestURLForSameDocumentNavigation(const KURL&);
        bool isStopping() const { return m_isStopping; }
        void stopLoading();
        void setCommitted(bool committed) { m_committed = committed; }
        bool isCommitted() const { return m_committed; }
        bool isLoading() const { return m_loading; }
        void setLoading(bool loading) { m_loading = loading; }
        void updateLoading();
        void receivedData(const char*, int);
        void setupForReplaceByMIMEType(const String& newMIMEType);
        void finishedLoading();
        const ResourceResponse& response() const { return m_response; }
        const ResourceError& mainDocumentError() const { return m_mainDocumentError; }
        void mainReceivedError(const ResourceError&, bool isComplete);
        void setResponse(const ResourceResponse& response) { m_response = response; }
        void prepareForLoadStart();
        bool isClientRedirect() const { return m_isClientRedirect; }
        void setIsClientRedirect(bool isClientRedirect) { m_isClientRedirect = isClientRedirect; }
        void handledOnloadEvents();
        bool wasOnloadHandled() { return m_wasOnloadHandled; }
        bool isLoadingInAPISense() const;
        void setPrimaryLoadComplete(bool);
        void setTitle(const StringWithDirection&);
        const String& overrideEncoding() const { return m_overrideEncoding; }

#if PLATFORM(MAC)
        void schedule(SchedulePair*);
        void unschedule(SchedulePair*);
#endif

#if ENABLE(WEB_ARCHIVE) || ENABLE(MHTML)
        void addAllArchiveResources(Archive*);
        void addArchiveResource(PassRefPtr<ArchiveResource>);
        
        PassRefPtr<Archive> popArchiveForSubframe(const String& frameName, const KURL&);
        void clearArchiveResources();
        void setParsedArchiveData(PassRefPtr<SharedBuffer>);
        SharedBuffer* parsedArchiveData() const;
        
        bool scheduleArchiveLoad(ResourceLoader*, const ResourceRequest&, const KURL&);
#endif // ENABLE(WEB_ARCHIVE) || ENABLE(MHTML)

        // Return the ArchiveResource for the URL only when loading an Archive
        ArchiveResource* archiveResourceForURL(const KURL&) const;

        PassRefPtr<ArchiveResource> mainResource() const;

        // Return an ArchiveResource for the URL, either creating from live data or
        // pulling from the ArchiveResourceCollection
        PassRefPtr<ArchiveResource> subresource(const KURL&) const;
        void getSubresources(Vector<PassRefPtr<ArchiveResource> >&) const;


#ifndef NDEBUG
        bool isSubstituteLoadPending(ResourceLoader*) const;
#endif
        void cancelPendingSubstituteLoad(ResourceLoader*);   
        
        void addResponse(const ResourceResponse&);
        const ResponseVector& responses() const { return m_responses; }

        const NavigationAction& triggeringAction() const { return m_triggeringAction; }
        void setTriggeringAction(const NavigationAction& action) { m_triggeringAction = action; }
        void setOverrideEncoding(const String& encoding) { m_overrideEncoding = encoding; }
        void setLastCheckedRequest(const ResourceRequest& request) { m_lastCheckedRequest = request; }
        const ResourceRequest& lastCheckedRequest()  { return m_lastCheckedRequest; }

        void stopRecordingResponses();
        const StringWithDirection& title() const { return m_pageTitle; }

        KURL urlForHistory() const;
        bool urlForHistoryReflectsFailure() const;

        // These accessors accommodate WebCore's somewhat fickle custom of creating history
        // items for redirects, but only sometimes. For "source" and "destination",
        // these accessors return the URL that would have been used if a history
        // item were created. This allows WebKit to link history items reflecting
        // redirects into a chain from start to finish.
        String clientRedirectSourceForHistory() const { return m_clientRedirectSourceForHistory; } // null if no client redirect occurred.
        String clientRedirectDestinationForHistory() const { return urlForHistory(); }
        void setClientRedirectSourceForHistory(const String& clientedirectSourceForHistory) { m_clientRedirectSourceForHistory = clientedirectSourceForHistory; }
        
        String serverRedirectSourceForHistory() const { return urlForHistory() == url() ? String() : urlForHistory().string(); } // null if no server redirect occurred.
        String serverRedirectDestinationForHistory() const { return url(); }

        bool didCreateGlobalHistoryEntry() const { return m_didCreateGlobalHistoryEntry; }
        void setDidCreateGlobalHistoryEntry(bool didCreateGlobalHistoryEntry) { m_didCreateGlobalHistoryEntry = didCreateGlobalHistoryEntry; }
        
        void setDefersLoading(bool);

        bool startLoadingMainResource(unsigned long identifier);
        void cancelMainResourceLoad(const ResourceError&);
        
        // Support iconDatabase in synchronous mode.
        void iconLoadDecisionAvailable();
        
        // Support iconDatabase in asynchronous mode.
        void continueIconLoadWithDecision(IconLoadDecision);
        void getIconLoadDecisionForIconURL(const String&);
        void getIconDataForIconURL(const String&);
        
        bool isLoadingMainResource() const;
        bool isLoadingSubresources() const;
        bool isLoadingPlugIns() const;
        bool isLoadingMultipartContent() const;

        void stopLoadingPlugIns();
        void stopLoadingSubresources();

        void addSubresourceLoader(ResourceLoader*);
        void removeSubresourceLoader(ResourceLoader*);
        void addPlugInStreamLoader(ResourceLoader*);
        void removePlugInStreamLoader(ResourceLoader*);

        void subresourceLoaderFinishedLoadingOnePart(ResourceLoader*);

        void transferLoadingResourcesFromPage(Page*);

        void maybeFinishLoadingMultipartContent();

        void setDeferMainResourceDataLoad(bool defer) { m_deferMainResourceDataLoad = defer; }
        bool deferMainResourceDataLoad() const { return m_deferMainResourceDataLoad; }
        
        void didTellClientAboutLoad(const String& url)
        { 
#if !PLATFORM(MAC)
            // Don't include data urls here, as if a lot of data is loaded
            // that way, we hold on to the (large) url string for too long.
            if (protocolIs(url, "data"))
                return;
#endif
            if (!url.isEmpty())
                m_resourcesClientKnowsAbout.add(url);
        }
        bool haveToldClientAboutLoad(const String& url) { return m_resourcesClientKnowsAbout.contains(url); }
        void recordMemoryCacheLoadForFutureClientNotification(const String& url);
        void takeMemoryCacheLoadsForClientNotification(Vector<String>& loads);

        DocumentLoadTiming* timing() { return &m_documentLoadTiming; }
        void resetTiming() { m_documentLoadTiming = DocumentLoadTiming(); }

        // The WebKit layer calls this function when it's ready for the data to
        // actually be added to the document.
        void commitData(const char* bytes, size_t length);

        ApplicationCacheHost* applicationCacheHost() const { return m_applicationCacheHost.get(); }

    protected:
        DocumentLoader(const ResourceRequest&, const SubstituteData&);

        bool m_deferMainResourceDataLoad;

    private:
        void setupForReplace();
        void commitIfReady();
        void clearErrors();
        void setMainDocumentError(const ResourceError&);
        void commitLoad(const char*, int);
        bool doesProgressiveLoad(const String& MIMEType) const;

        void deliverSubstituteResourcesAfterDelay();
        void substituteResourceDeliveryTimerFired(Timer<DocumentLoader>*);
                
        Frame* m_frame;

        RefPtr<MainResourceLoader> m_mainResourceLoader;
        ResourceLoaderSet m_subresourceLoaders;
        ResourceLoaderSet m_multipartSubresourceLoaders;
        ResourceLoaderSet m_plugInStreamLoaders;

        RefPtr<SharedBuffer> m_mainResourceData;
        
        mutable DocumentWriter m_writer;

        // A reference to actual request used to create the data source.
        // This should only be used by the resourceLoadDelegate's
        // identifierForInitialRequest:fromDatasource: method. It is
        // not guaranteed to remain unchanged, as requests are mutable.
        ResourceRequest m_originalRequest;   

        SubstituteData m_substituteData;

        // A copy of the original request used to create the data source.
        // We have to copy the request because requests are mutable.
        ResourceRequest m_originalRequestCopy;
        
        // The 'working' request. It may be mutated
        // several times from the original request to include additional
        // headers, cookie information, canonicalization and redirects.
        ResourceRequest m_request;

        ResourceResponse m_response;
    
        ResourceError m_mainDocumentError;    

        bool m_committed;
        bool m_isStopping;
        bool m_loading;
        bool m_gotFirstByte;
        bool m_primaryLoadComplete;
        bool m_isClientRedirect;

        // FIXME: Document::m_processingLoadEvent and DocumentLoader::m_wasOnloadHandled are roughly the same
        // and should be merged.
        bool m_wasOnloadHandled;

        StringWithDirection m_pageTitle;

        String m_overrideEncoding;

        // The action that triggered loading - we keep this around for the
        // benefit of the various policy handlers.
        NavigationAction m_triggeringAction;

        // The last request that we checked click policy for - kept around
        // so we can avoid asking again needlessly.
        ResourceRequest m_lastCheckedRequest;

        // We retain all the received responses so we can play back the
        // WebResourceLoadDelegate messages if the item is loaded from the
        // page cache.
        ResponseVector m_responses;
        bool m_stopRecordingResponses;
        
        typedef HashMap<RefPtr<ResourceLoader>, RefPtr<SubstituteResource> > SubstituteResourceMap;
        SubstituteResourceMap m_pendingSubstituteResources;
        Timer<DocumentLoader> m_substituteResourceDeliveryTimer;

        OwnPtr<ArchiveResourceCollection> m_archiveResourceCollection;
#if ENABLE(WEB_ARCHIVE) || ENABLE(MHTML)
        RefPtr<SharedBuffer> m_parsedArchiveData;
#endif

        HashSet<String> m_resourcesClientKnowsAbout;
        Vector<String> m_resourcesLoadedFromMemoryCacheForClientNotification;
        
        String m_clientRedirectSourceForHistory;
        bool m_didCreateGlobalHistoryEntry;

        DocumentLoadTiming m_documentLoadTiming;
    
        RefPtr<IconLoadDecisionCallback> m_iconLoadDecisionCallback;
        RefPtr<IconDataCallback> m_iconDataCallback;

        friend class ApplicationCacheHost;  // for substitute resource delivery
        OwnPtr<ApplicationCacheHost> m_applicationCacheHost;
    };

    inline void DocumentLoader::recordMemoryCacheLoadForFutureClientNotification(const String& url)
    {
        m_resourcesLoadedFromMemoryCacheForClientNotification.append(url);
    }

    inline void DocumentLoader::takeMemoryCacheLoadsForClientNotification(Vector<String>& loadsSet)
    {
        loadsSet.swap(m_resourcesLoadedFromMemoryCacheForClientNotification);
        m_resourcesLoadedFromMemoryCacheForClientNotification.clear();
    }

}

#endif // DocumentLoader_h
