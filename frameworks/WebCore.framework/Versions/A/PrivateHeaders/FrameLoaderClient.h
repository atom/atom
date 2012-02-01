/*
 * Copyright (C) 2006, 2007, 2008, 2009, 2010, 2011 Apple Inc. All rights reserved.
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

#ifndef FrameLoaderClient_h
#define FrameLoaderClient_h

#include "FrameLoaderTypes.h"
#include "IconURL.h"
#include <wtf/Forward.h>
#include <wtf/Vector.h>

#if PLATFORM(MAC)
#ifdef __OBJC__ 
#import <Foundation/Foundation.h>
typedef id RemoteAXObjectRef;
#else
typedef void* RemoteAXObjectRef;
#endif
#endif

typedef class _jobject* jobject;

#if PLATFORM(MAC) && !defined(__OBJC__)
class NSCachedURLResponse;
class NSView;
#endif

#if USE(V8)
namespace v8 {
class Context;
template<class T> class Handle;
}
#endif

namespace WebCore {

    class AuthenticationChallenge;
    class CachedFrame;
    class Color;
    class DOMWrapperWorld;
    class DocumentLoader;
    class Element;
    class FormState;
    class Frame;
    class FrameLoader;
    class FrameNetworkingContext;
    class HistoryItem;
    class HTMLAppletElement;
    class HTMLFormElement;
    class HTMLFrameOwnerElement;
#if ENABLE(PLUGIN_PROXY_FOR_VIDEO)
    class HTMLMediaElement;
#endif
    class HTMLPlugInElement;
    class IntSize;
#if ENABLE(WEB_INTENTS)
    class IntentRequest;
#endif
    class KURL;
    class MessageEvent;
    class NavigationAction;
    class Page;
    class ProtectionSpace;
    class PluginView;
    class PolicyChecker;
    class ResourceError;
    class ResourceHandle;
    class ResourceLoader;
    class ResourceRequest;
    class ResourceResponse;
    class SecurityOrigin;
    class SharedBuffer;
    class StringWithDirection;
    class SubstituteData;
    class Widget;

    typedef void (PolicyChecker::*FramePolicyFunction)(PolicyAction);

    class FrameLoaderClient {
    public:
        // An inline function cannot be the first non-abstract virtual function declared
        // in the class as it results in the vtable being generated as a weak symbol.
        // This hurts performance (in Mac OS X at least, when loadig frameworks), so we
        // don't want to do it in WebKit.
        virtual bool hasHTMLView() const;

        virtual ~FrameLoaderClient() { }

        virtual void frameLoaderDestroyed() = 0;

        virtual bool hasWebView() const = 0; // mainly for assertions

        virtual void makeRepresentation(DocumentLoader*) = 0;
        virtual void forceLayout() = 0;
        virtual void forceLayoutForNonHTML() = 0;

        virtual void setCopiesOnScroll() = 0;

        virtual void detachedFromParent2() = 0;
        virtual void detachedFromParent3() = 0;

        virtual void assignIdentifierToInitialRequest(unsigned long identifier, DocumentLoader*, const ResourceRequest&) = 0;

        virtual void dispatchWillSendRequest(DocumentLoader*, unsigned long identifier, ResourceRequest&, const ResourceResponse& redirectResponse) = 0;
        virtual bool shouldUseCredentialStorage(DocumentLoader*, unsigned long identifier) = 0;
        virtual void dispatchDidReceiveAuthenticationChallenge(DocumentLoader*, unsigned long identifier, const AuthenticationChallenge&) = 0;
        virtual void dispatchDidCancelAuthenticationChallenge(DocumentLoader*, unsigned long identifier, const AuthenticationChallenge&) = 0;        
#if USE(PROTECTION_SPACE_AUTH_CALLBACK)
        virtual bool canAuthenticateAgainstProtectionSpace(DocumentLoader*, unsigned long identifier, const ProtectionSpace&) = 0;
#endif
        virtual void dispatchDidReceiveResponse(DocumentLoader*, unsigned long identifier, const ResourceResponse&) = 0;
        virtual void dispatchDidReceiveContentLength(DocumentLoader*, unsigned long identifier, int dataLength) = 0;
        virtual void dispatchDidFinishLoading(DocumentLoader*, unsigned long identifier) = 0;
        virtual void dispatchDidFailLoading(DocumentLoader*, unsigned long identifier, const ResourceError&) = 0;
        virtual bool dispatchDidLoadResourceFromMemoryCache(DocumentLoader*, const ResourceRequest&, const ResourceResponse&, int length) = 0;

        virtual void dispatchDidHandleOnloadEvents() = 0;
        virtual void dispatchDidReceiveServerRedirectForProvisionalLoad() = 0;
        virtual void dispatchDidCancelClientRedirect() = 0;
        virtual void dispatchWillPerformClientRedirect(const KURL&, double interval, double fireDate) = 0;
        virtual void dispatchDidNavigateWithinPage() { }
        virtual void dispatchDidChangeLocationWithinPage() = 0;
        virtual void dispatchDidPushStateWithinPage() = 0;
        virtual void dispatchDidReplaceStateWithinPage() = 0;
        virtual void dispatchDidPopStateWithinPage() = 0;
        virtual void dispatchWillClose() = 0;
        virtual void dispatchDidReceiveIcon() = 0;
        virtual void dispatchDidStartProvisionalLoad() = 0;
        virtual void dispatchDidReceiveTitle(const StringWithDirection&) = 0;
        virtual void dispatchDidChangeIcons(IconType) = 0;
        virtual void dispatchDidCommitLoad() = 0;
        virtual void dispatchDidFailProvisionalLoad(const ResourceError&) = 0;
        virtual void dispatchDidFailLoad(const ResourceError&) = 0;
        virtual void dispatchDidFinishDocumentLoad() = 0;
        virtual void dispatchDidFinishLoad() = 0;

        virtual void dispatchDidFirstLayout() = 0;
        virtual void dispatchDidFirstVisuallyNonEmptyLayout() = 0;
        virtual void dispatchDidLayout() { }

        virtual Frame* dispatchCreatePage(const NavigationAction&) = 0;
        virtual void dispatchShow() = 0;

        virtual void dispatchDecidePolicyForResponse(FramePolicyFunction, const ResourceResponse&, const ResourceRequest&) = 0;
        virtual void dispatchDecidePolicyForNewWindowAction(FramePolicyFunction, const NavigationAction&, const ResourceRequest&, PassRefPtr<FormState>, const String& frameName) = 0;
        virtual void dispatchDecidePolicyForNavigationAction(FramePolicyFunction, const NavigationAction&, const ResourceRequest&, PassRefPtr<FormState>) = 0;
        virtual void cancelPolicyCheck() = 0;

        virtual void dispatchUnableToImplementPolicy(const ResourceError&) = 0;

        virtual void dispatchWillSendSubmitEvent(HTMLFormElement*) = 0;
        virtual void dispatchWillSubmitForm(FramePolicyFunction, PassRefPtr<FormState>) = 0;

        virtual void dispatchDidLoadMainResource(DocumentLoader*) = 0;
        virtual void revertToProvisionalState(DocumentLoader*) = 0;
        virtual void setMainDocumentError(DocumentLoader*, const ResourceError&) = 0;

        // Maybe these should go into a ProgressTrackerClient some day
        virtual void willChangeEstimatedProgress() { }
        virtual void didChangeEstimatedProgress() { }
        virtual void postProgressStartedNotification() = 0;
        virtual void postProgressEstimateChangedNotification() = 0;
        virtual void postProgressFinishedNotification() = 0;
        
        virtual void setMainFrameDocumentReady(bool) = 0;

        virtual void startDownload(const ResourceRequest&, const String& suggestedName = String()) = 0;

        virtual void willChangeTitle(DocumentLoader*) = 0;
        virtual void didChangeTitle(DocumentLoader*) = 0;

        virtual void committedLoad(DocumentLoader*, const char*, int) = 0;
        virtual void finishedLoading(DocumentLoader*) = 0;
        
        virtual void updateGlobalHistory() = 0;
        virtual void updateGlobalHistoryRedirectLinks() = 0;

        virtual bool shouldGoToHistoryItem(HistoryItem*) const = 0;
        virtual bool shouldStopLoadingForHistoryItem(HistoryItem*) const = 0;
        virtual void updateGlobalHistoryItemForPage() { }

        // This frame has displayed inactive content (such as an image) from an
        // insecure source.  Inactive content cannot spread to other frames.
        virtual void didDisplayInsecureContent() = 0;

        // The indicated security origin has run active content (such as a
        // script) from an insecure source.  Note that the insecure content can
        // spread to other frames in the same origin.
        virtual void didRunInsecureContent(SecurityOrigin*, const KURL&) = 0;
        virtual void didDetectXSS(const KURL&, bool didBlockEntirePage) = 0;

        virtual ResourceError cancelledError(const ResourceRequest&) = 0;
        virtual ResourceError blockedError(const ResourceRequest&) = 0;
        virtual ResourceError cannotShowURLError(const ResourceRequest&) = 0;
        virtual ResourceError interruptedForPolicyChangeError(const ResourceRequest&) = 0;

        virtual ResourceError cannotShowMIMETypeError(const ResourceResponse&) = 0;
        virtual ResourceError fileDoesNotExistError(const ResourceResponse&) = 0;
        virtual ResourceError pluginWillHandleLoadError(const ResourceResponse&) = 0;

        virtual bool shouldFallBack(const ResourceError&) = 0;

        virtual bool canHandleRequest(const ResourceRequest&) const = 0;
        virtual bool canShowMIMEType(const String& MIMEType) const = 0;
        virtual bool canShowMIMETypeAsHTML(const String& MIMEType) const = 0;
        virtual bool representationExistsForURLScheme(const String& URLScheme) const = 0;
        virtual String generatedMIMETypeForURLScheme(const String& URLScheme) const = 0;

        virtual void frameLoadCompleted() = 0;
        virtual void saveViewStateToItem(HistoryItem*) = 0;
        virtual void restoreViewState() = 0;
        virtual void provisionalLoadStarted() = 0;
        virtual void didFinishLoad() = 0;
        virtual void prepareForDataSourceReplacement() = 0;

        virtual PassRefPtr<DocumentLoader> createDocumentLoader(const ResourceRequest&, const SubstituteData&) = 0;
        virtual void setTitle(const StringWithDirection&, const KURL&) = 0;

        virtual String userAgent(const KURL&) = 0;
        
        virtual void savePlatformDataToCachedFrame(CachedFrame*) = 0;
        virtual void transitionToCommittedFromCachedFrame(CachedFrame*) = 0;
        virtual void transitionToCommittedForNewPage() = 0;

        virtual void didSaveToPageCache() = 0;
        virtual void didRestoreFromPageCache() = 0;

        virtual void dispatchDidBecomeFrameset(bool) = 0; // Can change due to navigation or DOM modification.

        virtual bool canCachePage() const = 0;
        virtual void download(ResourceHandle*, const ResourceRequest&, const ResourceResponse&) = 0;

        virtual PassRefPtr<Frame> createFrame(const KURL& url, const String& name, HTMLFrameOwnerElement* ownerElement,
                                   const String& referrer, bool allowsScrolling, int marginWidth, int marginHeight) = 0;
        virtual void didTransferChildFrameToNewDocument(Page* oldPage) = 0;
        virtual void transferLoadingResourceFromPage(ResourceLoader*, const ResourceRequest&, Page* oldPage) = 0;
        virtual PassRefPtr<Widget> createPlugin(const IntSize&, HTMLPlugInElement*, const KURL&, const Vector<String>&, const Vector<String>&, const String&, bool loadManually) = 0;
        virtual void redirectDataToPlugin(Widget* pluginWidget) = 0;

        virtual PassRefPtr<Widget> createJavaAppletWidget(const IntSize&, HTMLAppletElement*, const KURL& baseURL, const Vector<String>& paramNames, const Vector<String>& paramValues) = 0;

        virtual void dispatchDidFailToStartPlugin(const PluginView*) const { }
#if ENABLE(PLUGIN_PROXY_FOR_VIDEO)
        virtual PassRefPtr<Widget> createMediaPlayerProxyPlugin(const IntSize&, HTMLMediaElement*, const KURL&, const Vector<String>&, const Vector<String>&, const String&) = 0;
        virtual void hideMediaPlayerProxyPlugin(Widget*) = 0;
        virtual void showMediaPlayerProxyPlugin(Widget*) = 0;
#endif

        virtual ObjectContentType objectContentType(const KURL&, const String& mimeType, bool shouldPreferPlugInsForImages) = 0;
        virtual String overrideMediaType() const = 0;

        virtual void dispatchDidClearWindowObjectInWorld(DOMWrapperWorld*) = 0;
        virtual void documentElementAvailable() = 0;
        virtual void didPerformFirstNavigation() const = 0; // "Navigation" here means a transition from one page to another that ends up in the back/forward list.

#if USE(V8)
        virtual void didCreateScriptContext(v8::Handle<v8::Context>, int worldId) = 0;
        virtual void willReleaseScriptContext(v8::Handle<v8::Context>, int worldId) = 0;
        virtual bool allowScriptExtension(const String& extensionName, int extensionGroup, int worldId) = 0;
#endif

        virtual void registerForIconNotification(bool listen = true) = 0;
        
#if PLATFORM(MAC)
        // Allow an accessibility object to retrieve a Frame parent if there's no PlatformWidget.
        virtual RemoteAXObjectRef accessibilityRemoteObject() = 0;
#if ENABLE(JAVA_BRIDGE)
        virtual jobject javaApplet(NSView*) { return 0; }
#endif
        virtual NSCachedURLResponse* willCacheResponse(DocumentLoader*, unsigned long identifier, NSCachedURLResponse*) const = 0;
#endif
#if PLATFORM(WIN) && USE(CFNETWORK)
        // FIXME: Windows should use willCacheResponse - <https://bugs.webkit.org/show_bug.cgi?id=57257>.
        virtual bool shouldCacheResponse(DocumentLoader*, unsigned long identifier, const ResourceResponse&, const unsigned char* data, unsigned long long length) = 0;
#endif

        virtual bool shouldUsePluginDocument(const String& /*mimeType*/) const { return false; }
        virtual bool shouldLoadMediaElementURL(const KURL&) const { return true; }

        virtual void didChangeScrollOffset() { }

        virtual bool allowScript(bool enabledPerSettings) { return enabledPerSettings; }
        virtual bool allowScriptFromSource(bool enabledPerSettings, const KURL&) { return enabledPerSettings; }
        virtual bool allowPlugins(bool enabledPerSettings) { return enabledPerSettings; }
        virtual bool allowImage(bool enabledPerSettings, const KURL&) { return enabledPerSettings; }
        virtual bool allowDisplayingInsecureContent(bool enabledPerSettings, SecurityOrigin*, const KURL&) { return enabledPerSettings; }
        virtual bool allowRunningInsecureContent(bool enabledPerSettings, SecurityOrigin*, const KURL&) { return enabledPerSettings; }
        
        // This callback notifies the client that the frame was about to run
        // JavaScript but did not because allowScript returned false. We
        // have a separate callback here because there are a number of places
        // that need to know if JavaScript is enabled but are not necessarily
        // preparing to execute script.
        virtual void didNotAllowScript() { }
        // This callback is similar, but for plugins.
        virtual void didNotAllowPlugins() { }

        virtual PassRefPtr<FrameNetworkingContext> createNetworkingContext() = 0;

        virtual bool shouldPaintBrokenImage(const KURL&) const { return true; }

        // Returns true if the embedder intercepted the postMessage call
        virtual bool willCheckAndDispatchMessageEvent(SecurityOrigin* /*target*/, MessageEvent*) const { return false; }

#if ENABLE(WEB_INTENTS)
        virtual void dispatchIntent(PassRefPtr<IntentRequest>) = 0;
#endif
    };

} // namespace WebCore

#endif // FrameLoaderClient_h
