/*
 * Copyright (C) 2009 Apple Inc. All rights reserved.
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

#ifndef InspectorDOMAgent_h
#define InspectorDOMAgent_h

#include "EventTarget.h"
#include "InjectedScript.h"
#include "InjectedScriptManager.h"
#include "InspectorBaseAgent.h"
#include "InspectorFrontend.h"
#include "InspectorValues.h"
#include "Timer.h"

#include <wtf/Deque.h>
#include <wtf/ListHashSet.h>
#include <wtf/HashMap.h>
#include <wtf/HashSet.h>
#include <wtf/OwnPtr.h>
#include <wtf/PassOwnPtr.h>
#include <wtf/RefPtr.h>
#include <wtf/Vector.h>
#include <wtf/text/AtomicString.h>

namespace WebCore {
class ContainerNode;
class CharacterData;
class Document;
class Element;
class Event;
class GraphicsContext;
class InspectorClient;
class InspectorDOMAgent;
class InspectorFrontend;
class InspectorPageAgent;
class IntRect;
class HitTestResult;
class HTMLElement;
class InspectorState;
class InstrumentingAgents;
class NameNodeMap;
class Node;
class RevalidateStyleAttributeTask;
class ScriptValue;

struct Highlight;
struct HighlightData;

typedef String ErrorString;

#if ENABLE(INSPECTOR)

struct EventListenerInfo {
    EventListenerInfo(Node* node, const AtomicString& eventType, const EventListenerVector& eventListenerVector)
        : node(node)
        , eventType(eventType)
        , eventListenerVector(eventListenerVector)
    {
    }

    Node* node;
    const AtomicString eventType;
    const EventListenerVector eventListenerVector;
};

class InspectorDOMAgent : public InspectorBaseAgent<InspectorDOMAgent> {
    WTF_MAKE_NONCOPYABLE(InspectorDOMAgent);
public:
    struct DOMListener {
        virtual ~DOMListener()
        {
        }
        virtual void didRemoveDocument(Document*) = 0;
        virtual void didRemoveDOMNode(Node*) = 0;
        virtual void didModifyDOMAttr(Element*) = 0;
    };

    static PassOwnPtr<InspectorDOMAgent> create(InstrumentingAgents* instrumentingAgents, InspectorPageAgent* pageAgent, InspectorClient* client, InspectorState* inspectorState, InjectedScriptManager* injectedScriptManager)
    {
        return adoptPtr(new InspectorDOMAgent(instrumentingAgents, pageAgent, client, inspectorState, injectedScriptManager));
    }

    ~InspectorDOMAgent();

    virtual void setFrontend(InspectorFrontend*);
    virtual void clearFrontend();
    virtual void restore();

    Vector<Document*> documents();
    void reset();

    // Methods called from the frontend for DOM nodes inspection.
    void querySelector(ErrorString*, int nodeId, const String& selectors, int* elementId);
    void querySelectorAll(ErrorString*, int nodeId, const String& selectors, RefPtr<InspectorArray>& result);
    void getDocument(ErrorString*, RefPtr<InspectorObject>& root);
    void requestChildNodes(ErrorString*, int nodeId);
    void setAttributeValue(ErrorString*, int elementId, const String& name, const String& value);
    void setAttributesAsText(ErrorString*, int elementId, const String& text, const String* const name);
    void removeAttribute(ErrorString*, int elementId, const String& name);
    void removeNode(ErrorString*, int nodeId);
    void setNodeName(ErrorString*, int nodeId, const String& name, int* newId);
    void getOuterHTML(ErrorString*, int nodeId, WTF::String* outerHTML);
    void setOuterHTML(ErrorString*, int nodeId, const String& outerHTML);
    void setNodeValue(ErrorString*, int nodeId, const String& value);
    void getEventListenersForNode(ErrorString*, int nodeId, RefPtr<InspectorArray>& listenersArray);
    void performSearch(ErrorString*, const String& whitespaceTrimmedQuery, String* searchId, int* resultCount);
    void getSearchResults(ErrorString*, const String& searchId, int fromIndex, int toIndex, RefPtr<InspectorArray>&);
    void discardSearchResults(ErrorString*, const String& searchId);
    void resolveNode(ErrorString*, int nodeId, const String* const objectGroup, RefPtr<InspectorObject>& result);
    void getAttributes(ErrorString*, int nodeId, RefPtr<InspectorArray>& result);
    void setInspectModeEnabled(ErrorString*, bool enabled, const RefPtr<InspectorObject>* highlightConfig);
    void requestNode(ErrorString*, const String& objectId, int* nodeId);
    void pushNodeByPathToFrontend(ErrorString*, const String& path, int* nodeId);
    void hideHighlight(ErrorString*);
    void highlightRect(ErrorString*, int x, int y, int width, int height, const RefPtr<InspectorObject>* color, const RefPtr<InspectorObject>* outlineColor);
    void highlightNode(ErrorString*, int nodeId, const RefPtr<InspectorObject> highlightConfig);
    void highlightFrame(ErrorString*, const String& frameId, const RefPtr<InspectorObject>* color, const RefPtr<InspectorObject>* outlineColor);
    void moveTo(ErrorString*, int nodeId, int targetNodeId, const int* const anchorNodeId, int* newNodeId);

    Node* highlightedNode() const;

    // Methods called from the InspectorInstrumentation.
    void setDocument(Document*);
    void releaseDanglingNodes();

    void mainFrameDOMContentLoaded();
    void loadEventFired(Document*);

    void didInsertDOMNode(Node*);
    void didRemoveDOMNode(Node*);
    void didModifyDOMAttr(Element*, const AtomicString& name, const AtomicString& value);
    void didRemoveDOMAttr(Element*, const AtomicString& name);
    void styleAttributeInvalidated(const Vector<Element*>& elements);
    void characterDataModified(CharacterData*);
    void didInvalidateStyleAttr(Node*);

    Node* nodeForId(int nodeId);
    int boundNodeId(Node*);
    void setDOMListener(DOMListener*);

    static String documentURLString(Document*);

    PassRefPtr<InspectorObject> resolveNode(Node*, const String& objectGroup);
    bool handleMousePress();
    void mouseDidMoveOverElement(const HitTestResult&, unsigned modifierFlags);
    void inspect(Node*);
    void focusNode();

    void drawHighlight(GraphicsContext&) const;
    void getHighlight(Highlight*) const;

    // We represent embedded doms as a part of the same hierarchy. Hence we treat children of frame owners differently.
    // We also skip whitespace text nodes conditionally. Following methods encapsulate these specifics.
    static Node* innerFirstChild(Node*);
    static Node* innerNextSibling(Node*);
    static Node* innerPreviousSibling(Node*);
    static unsigned innerChildNodeCount(Node*);
    static Node* innerParentNode(Node*);
    static bool isWhitespace(Node*);

    Node* assertNode(ErrorString*, int nodeId);

private:
    InspectorDOMAgent(InstrumentingAgents*, InspectorPageAgent*, InspectorClient*, InspectorState*, InjectedScriptManager*);

    void setSearchingForNode(bool enabled, InspectorObject* highlightConfig);
    bool setHighlightDataFromConfig(InspectorObject* highlightConfig);
    void highlight();

    // Node-related methods.
    typedef HashMap<RefPtr<Node>, int> NodeToIdMap;
    int bind(Node*, NodeToIdMap*);
    void unbind(Node*, NodeToIdMap*);
    Element* assertElement(ErrorString*, int nodeId);
    HTMLElement* assertHTMLElement(ErrorString*, int nodeId);

    int pushNodePathToFrontend(Node*);
    void pushChildNodesToFrontend(int nodeId);

    bool hasBreakpoint(Node*, int type);
    void updateSubtreeBreakpoints(Node* root, uint32_t rootMask, bool value);
    void descriptionForDOMEvent(Node* target, int breakpointType, bool insertion, PassRefPtr<InspectorObject> description);

    PassRefPtr<InspectorObject> buildObjectForNode(Node*, int depth, NodeToIdMap*);
    PassRefPtr<InspectorArray> buildArrayForElementAttributes(Element*);
    PassRefPtr<InspectorArray> buildArrayForContainerChildren(Node* container, int depth, NodeToIdMap* nodesMap);
    PassRefPtr<InspectorObject> buildObjectForEventListener(const RegisteredEventListener&, const AtomicString& eventType, Node*);

    Node* nodeForPath(const String& path);

    void discardBindings();

    InspectorPageAgent* m_pageAgent;
    InspectorClient* m_client;
    InjectedScriptManager* m_injectedScriptManager;
    InspectorFrontend::DOM* m_frontend;
    DOMListener* m_domListener;
    NodeToIdMap m_documentNodeToIdMap;
    // Owns node mappings for dangling nodes.
    Vector<NodeToIdMap*> m_danglingNodeToIdMaps;
    HashMap<int, Node*> m_idToNode;
    HashMap<int, NodeToIdMap*> m_idToNodesMap;
    HashSet<int> m_childrenRequested;
    int m_lastNodeId;
    RefPtr<Document> m_document;
    typedef HashMap<String, Vector<RefPtr<Node> > > SearchResults;
    SearchResults m_searchResults;
    OwnPtr<RevalidateStyleAttributeTask> m_revalidateStyleAttrTask;
    OwnPtr<HighlightData> m_highlightData;
    RefPtr<Node> m_nodeToFocus;
    bool m_searchingForNode;
};

#endif // ENABLE(INSPECTOR)

} // namespace WebCore

#endif // !defined(InspectorDOMAgent_h)
