/*
 * Copyright (C) 1999 Lars Knoll (knoll@kde.org)
 *           (C) 1999 Antti Koivisto (koivisto@kde.org)
 *           (C) 2001 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011 Apple Inc. All rights reserved.
 * Copyright (C) 2008, 2009 Torch Mobile Inc. All rights reserved. (http://www.torchmobile.com/)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 */

#ifndef Node_h
#define Node_h

#include "EditingBoundary.h"
#include "EventTarget.h"
#include "KURLHash.h"
#include "LayoutTypes.h"
#include "RenderStyleConstants.h"
#include "ScriptWrappable.h"
#include "TreeShared.h"
#include "WebKitMutationObserver.h"
#include <wtf/Forward.h>
#include <wtf/ListHashSet.h>
#include <wtf/text/AtomicString.h>

#if USE(JSC)
namespace JSC {
    class JSGlobalData;
    class SlotVisitor;
}
#endif

namespace WebCore {

class Attribute;
class ClassNodeList;
class ContainerNode;
class DOMSettableTokenList;
class Document;
class DynamicSubtreeNodeList;
class Element;
class Event;
class EventContext;
class EventDispatchMediator;
class EventListener;
class FloatPoint;
class Frame;
class HTMLInputElement;
class IntRect;
class KeyboardEvent;
class NSResolver;
class NamedNodeMap;
class NameNodeList;
class NodeList;
class NodeRareData;
class NodeRenderingContext;
class PlatformKeyboardEvent;
class PlatformMouseEvent;
class PlatformWheelEvent;
class QualifiedName;
class RegisteredEventListener;
class RenderArena;
class RenderBox;
class RenderBoxModelObject;
class RenderObject;
class RenderStyle;
#if ENABLE(SVG)
class SVGUseElement;
#endif
class TagNodeList;
class TreeScope;

#if ENABLE(MICRODATA)
class HTMLPropertiesCollection;
#endif

typedef int ExceptionCode;

const int nodeStyleChangeShift = 25;

// SyntheticStyleChange means that we need to go through the entire style change logic even though
// no style property has actually changed. It is used to restructure the tree when, for instance,
// RenderLayers are created or destroyed due to animation changes.
enum StyleChangeType { 
    NoStyleChange = 0, 
    InlineStyleChange = 1 << nodeStyleChangeShift, 
    FullStyleChange = 2 << nodeStyleChangeShift, 
    SyntheticStyleChange = 3 << nodeStyleChangeShift
};

class Node : public EventTarget, public ScriptWrappable, public TreeShared<ContainerNode> {
    friend class Document;
    friend class TreeScope;
    friend class TreeScopeAdopter;

public:
    enum NodeType {
        ELEMENT_NODE = 1,
        ATTRIBUTE_NODE = 2,
        TEXT_NODE = 3,
        CDATA_SECTION_NODE = 4,
        ENTITY_REFERENCE_NODE = 5,
        ENTITY_NODE = 6,
        PROCESSING_INSTRUCTION_NODE = 7,
        COMMENT_NODE = 8,
        DOCUMENT_NODE = 9,
        DOCUMENT_TYPE_NODE = 10,
        DOCUMENT_FRAGMENT_NODE = 11,
        NOTATION_NODE = 12,
        XPATH_NAMESPACE_NODE = 13,
        SHADOW_ROOT_NODE = 14
    };
    enum DocumentPosition {
        DOCUMENT_POSITION_EQUIVALENT = 0x00,
        DOCUMENT_POSITION_DISCONNECTED = 0x01,
        DOCUMENT_POSITION_PRECEDING = 0x02,
        DOCUMENT_POSITION_FOLLOWING = 0x04,
        DOCUMENT_POSITION_CONTAINS = 0x08,
        DOCUMENT_POSITION_CONTAINED_BY = 0x10,
        DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = 0x20,
    };

    static bool isSupported(const String& feature, const String& version);

    static void startIgnoringLeaks();
    static void stopIgnoringLeaks();

    static void dumpStatistics();

    enum StyleChange { NoChange, NoInherit, Inherit, Detach, Force };    
    static StyleChange diff(const RenderStyle*, const RenderStyle*);

    virtual ~Node();

    // DOM methods & attributes for Node

    bool hasTagName(const QualifiedName&) const;
    bool hasLocalName(const AtomicString&) const;
    virtual String nodeName() const = 0;
    virtual String nodeValue() const;
    virtual void setNodeValue(const String&, ExceptionCode&);
    virtual NodeType nodeType() const = 0;
    ContainerNode* parentNode() const;
    Element* parentElement() const;
    Node* previousSibling() const { return m_previous; }
    Node* nextSibling() const { return m_next; }
    PassRefPtr<NodeList> childNodes();
    Node* firstChild() const;
    Node* lastChild() const;
    bool hasAttributes() const;
    NamedNodeMap* attributes() const;

    virtual KURL baseURI() const;
    
    void getSubresourceURLs(ListHashSet<KURL>&) const;

    // These should all actually return a node, but this is only important for language bindings,
    // which will already know and hold a ref on the right node to return. Returning bool allows
    // these methods to be more efficient since they don't need to return a ref
    bool insertBefore(PassRefPtr<Node> newChild, Node* refChild, ExceptionCode&, bool shouldLazyAttach = false);
    bool replaceChild(PassRefPtr<Node> newChild, Node* oldChild, ExceptionCode&, bool shouldLazyAttach = false);
    bool removeChild(Node* child, ExceptionCode&);
    bool appendChild(PassRefPtr<Node> newChild, ExceptionCode&, bool shouldLazyAttach = false);

    void remove(ExceptionCode&);
    bool hasChildNodes() const { return firstChild(); }
    virtual PassRefPtr<Node> cloneNode(bool deep) = 0;
    const AtomicString& localName() const { return virtualLocalName(); }
    const AtomicString& namespaceURI() const { return virtualNamespaceURI(); }
    const AtomicString& prefix() const { return virtualPrefix(); }
    virtual void setPrefix(const AtomicString&, ExceptionCode&);
    void normalize();

    bool isSameNode(Node* other) const { return this == other; }
    bool isEqualNode(Node*) const;
    bool isDefaultNamespace(const AtomicString& namespaceURI) const;
    String lookupPrefix(const AtomicString& namespaceURI) const;
    String lookupNamespaceURI(const String& prefix) const;
    String lookupNamespacePrefix(const AtomicString& namespaceURI, const Element* originalElement) const;
    
    String textContent(bool convertBRsToNewlines = false) const;
    void setTextContent(const String&, ExceptionCode&);
    
    Node* lastDescendant() const;
    Node* firstDescendant() const;

    virtual bool isActiveNode() const { return false; }
    
    // Other methods (not part of DOM)

    bool isElementNode() const { return getFlag(IsElementFlag); }
    bool isContainerNode() const { return getFlag(IsContainerFlag); }
    bool isTextNode() const { return getFlag(IsTextFlag); }

    bool isHTMLElement() const { return getFlag(IsHTMLFlag); }

    bool isSVGElement() const { return getFlag(IsSVGFlag); }
    bool isSVGShadowRoot() const { return getFlag(IsShadowRootOrSVGShadowRootFlag) && isSVGElement(); }
#if ENABLE(SVG)
    SVGUseElement* svgShadowHost() const;
#endif

    virtual bool isMediaControlElement() const { return false; }
    virtual bool isMediaControls() const { return false; }
    bool isStyledElement() const { return getFlag(IsStyledElementFlag); }
    virtual bool isFrameOwnerElement() const { return false; }
    virtual bool isAttributeNode() const { return false; }
    bool isCommentNode() const { return getFlag(IsCommentFlag); }
    virtual bool isCharacterDataNode() const { return false; }
    bool isDocumentNode() const;
    bool isShadowRoot() const { return getFlag(IsShadowRootOrSVGShadowRootFlag) && !isSVGElement(); }
    virtual bool isContentElement() const { return false; }

    Node* shadowAncestorNode() const;
    // Returns 0, a ShadowRoot, or a legacy shadow root.
    Node* shadowTreeRootNode() const;
    // Returns 0, a child of ShadowRoot, or a legacy shadow root.
    Node* nonBoundaryShadowTreeRootNode();
    bool isInShadowTree();
    // Node's parent, shadow tree host, or SVG use.
    ContainerNode* parentOrHostNode() const;
    Element* parentOrHostElement() const;
    // Use when it's guaranteed to that shadowHost is 0 and svgShadowHost is 0.
    ContainerNode* parentNodeGuaranteedHostFree() const;
    // Returns the parent node, but 0 if the parent node is a ShadowRoot.
    ContainerNode* nonShadowBoundaryParentNode() const;

    Element* shadowHost() const;
    void setShadowHost(Element*);

    bool selfOrAncestorHasDirAutoAttribute() const { return getFlag(SelfOrAncestorHasDirAutoFlag); }
    void setSelfOrAncestorHasDirAutoAttribute(bool flag) { setFlag(flag, SelfOrAncestorHasDirAutoFlag); }

    // Returns the enclosing event parent node (or self) that, when clicked, would trigger a navigation.
    Node* enclosingLinkEventParentOrSelf();

    bool isBlockFlow() const;
    bool isBlockFlowOrBlockTable() const;
    
    // These low-level calls give the caller responsibility for maintaining the integrity of the tree.
    void setPreviousSibling(Node* previous) { m_previous = previous; }
    void setNextSibling(Node* next) { m_next = next; }

    virtual bool canContainRangeEndPoint() const { return false; }

    // FIXME: These two functions belong in editing -- "atomic node" is an editing concept.
    Node* previousNodeConsideringAtomicNodes() const;
    Node* nextNodeConsideringAtomicNodes() const;
    
    // Returns the next leaf node or 0 if there are no more.
    // Delivers leaf nodes as if the whole DOM tree were a linear chain of its leaf nodes.
    // Uses an editing-specific concept of what a leaf node is, and should probably be moved
    // out of the Node class into an editing-specific source file.
    Node* nextLeafNode() const;

    // Returns the previous leaf node or 0 if there are no more.
    // Delivers leaf nodes as if the whole DOM tree were a linear chain of its leaf nodes.
    // Uses an editing-specific concept of what a leaf node is, and should probably be moved
    // out of the Node class into an editing-specific source file.
    Node* previousLeafNode() const;

    // enclosingBlockFlowElement() is deprecated. Use enclosingBlock instead.
    Element* enclosingBlockFlowElement() const;
    
    Element* rootEditableElement() const;
    Element* rootEditableElement(EditableType) const;

    bool inSameContainingBlockFlowElement(Node*);

    // Called by the parser when this element's close tag is reached,
    // signaling that all child tags have been parsed and added.
    // This is needed for <applet> and <object> elements, which can't lay themselves out
    // until they know all of their nested <param>s. [Radar 3603191, 4040848].
    // Also used for script elements and some SVG elements for similar purposes,
    // but making parsing a special case in this respect should be avoided if possible.
    virtual void finishParsingChildren() { }
    virtual void beginParsingChildren() { }

    // Called on the focused node right before dispatching an unload event.
    virtual void aboutToUnload() { }

    // For <link> and <style> elements.
    virtual bool sheetLoaded() { return true; }
    virtual void startLoadingDynamicSheet() { ASSERT_NOT_REACHED(); }

    bool hasName() const { return getFlag(HasNameFlag); }
    bool hasID() const { return getFlag(HasIDFlag); }
    bool hasClass() const { return getFlag(HasClassFlag); }
    bool active() const { return getFlag(IsActiveFlag); }
    bool inActiveChain() const { return getFlag(InActiveChainFlag); }
    bool inDetach() const { return getFlag(InDetachFlag); }
    bool hovered() const { return getFlag(IsHoveredFlag); }
    bool focused() const { return hasRareData() ? rareDataFocused() : false; }
    bool attached() const { return getFlag(IsAttachedFlag); }
    void setAttached() { setFlag(IsAttachedFlag); }
    bool needsStyleRecalc() const { return styleChangeType() != NoStyleChange; }
    StyleChangeType styleChangeType() const { return static_cast<StyleChangeType>(m_nodeFlags & StyleChangeMask); }
    bool childNeedsStyleRecalc() const { return getFlag(ChildNeedsStyleRecalcFlag); }
    bool isLink() const { return getFlag(IsLinkFlag); }

    void setHasName(bool f) { setFlag(f, HasNameFlag); }
    void setHasID(bool f) { setFlag(f, HasIDFlag); }
    void setHasClass(bool f) { setFlag(f, HasClassFlag); }
    void setChildNeedsStyleRecalc() { setFlag(ChildNeedsStyleRecalcFlag); }
    void clearChildNeedsStyleRecalc() { clearFlag(ChildNeedsStyleRecalcFlag); }
    void setInDocument() { setFlag(InDocumentFlag); }
    void clearInDocument() { clearFlag(InDocumentFlag); }

    void setInActiveChain() { setFlag(InActiveChainFlag); }
    void clearInActiveChain() { clearFlag(InActiveChainFlag); }

    void setNeedsStyleRecalc(StyleChangeType changeType = FullStyleChange);
    void clearNeedsStyleRecalc() { m_nodeFlags &= ~StyleChangeMask; }
    virtual void scheduleSetNeedsStyleRecalc(StyleChangeType changeType = FullStyleChange) { setNeedsStyleRecalc(changeType); }

    void setIsLink(bool f) { setFlag(f, IsLinkFlag); }
    void setIsLink() { setFlag(IsLinkFlag); }
    void clearIsLink() { clearFlag(IsLinkFlag); }

    enum ShouldSetAttached {
        SetAttached,
        DoNotSetAttached
    };
    void lazyAttach(ShouldSetAttached = SetAttached);

    virtual void setFocus(bool = true);
    virtual void setActive(bool f = true, bool /*pause*/ = false) { setFlag(f, IsActiveFlag); }
    virtual void setHovered(bool f = true) { setFlag(f, IsHoveredFlag); }

    virtual short tabIndex() const;

    // Whether this kind of node can receive focus by default. Most nodes are
    // not focusable but some elements, such as form controls and links, are.
    virtual bool supportsFocus() const;
    // Whether the node can actually be focused.
    virtual bool isFocusable() const;
    virtual bool isKeyboardFocusable(KeyboardEvent*) const;
    virtual bool isMouseFocusable() const;
    virtual Node* focusDelegate();

    bool isContentEditable();
    bool isContentRichlyEditable();

    bool rendererIsEditable(EditableType editableType = ContentIsEditable) const
    {
        switch (editableType) {
        case ContentIsEditable:
            return rendererIsEditable(Editable);
        case HasEditableAXRole:
            return isEditableToAccessibility(Editable);
        }
        ASSERT_NOT_REACHED();
        return false;
    }

    bool rendererIsRichlyEditable(EditableType editableType = ContentIsEditable) const
    {
        switch (editableType) {
        case ContentIsEditable:
            return rendererIsEditable(RichlyEditable);
        case HasEditableAXRole:
            return isEditableToAccessibility(RichlyEditable);
        }
        ASSERT_NOT_REACHED();
        return false;
    }

    virtual bool shouldUseInputMethod();
    virtual LayoutRect getRect() const;
    LayoutRect renderRect(bool* isReplaced);

    // Returns true if the node has a non-empty bounding box in layout.
    // This does not 100% guarantee the user can see it, but is pretty close.
    // Note: This method only works properly after layout has occurred.
    bool hasNonEmptyBoundingBox() const;

    unsigned nodeIndex() const;

    // Returns the DOM ownerDocument attribute. This method never returns NULL, except in the case 
    // of (1) a Document node or (2) a DocumentType node that is not used with any Document yet. 
    Document* ownerDocument() const;

    // Returns the document associated with this node. This method never returns NULL, except in the case 
    // of a DocumentType node that is not used with any Document yet. A Document node returns itself.
    Document* document() const
    {
        ASSERT(this);
        // FIXME: below ASSERT is useful, but prevents the use of document() in the constructor or destructor
        // due to the virtual function call to nodeType().
        ASSERT(m_document || (nodeType() == DOCUMENT_TYPE_NODE && !inDocument()));
        return m_document;
    }

    TreeScope* treeScope() const;

    // Returns true if this node is associated with a document and is in its associated document's
    // node tree, false otherwise.
    bool inDocument() const 
    { 
        ASSERT(m_document || !getFlag(InDocumentFlag));
        return getFlag(InDocumentFlag);
    }

    bool isReadOnlyNode() const { return nodeType() == ENTITY_REFERENCE_NODE; }
    virtual bool childTypeAllowed(NodeType) const { return false; }
    unsigned childNodeCount() const;
    Node* childNode(unsigned index) const;

    // Does a pre-order traversal of the tree to find the next node after this one.
    // This uses the same order that tags appear in the source file. If the stayWithin
    // argument is non-null, the traversal will stop once the specified node is reached.
    // This can be used to restrict traversal to a particular sub-tree.
    Node* traverseNextNode(const Node* stayWithin = 0) const;

    // Like traverseNextNode, but skips children and starts with the next sibling.
    Node* traverseNextSibling(const Node* stayWithin = 0) const;

    // Does a reverse pre-order traversal to find the node that comes before the current one in document order
    Node* traversePreviousNode(const Node* stayWithin = 0) const;

    // Like traversePreviousNode, but skips children and starts with the next sibling.
    Node* traversePreviousSibling(const Node* stayWithin = 0) const;

    // Like traverseNextNode, but visits parents after their children.
    Node* traverseNextNodePostOrder() const;

    // Like traversePreviousNode, but visits parents before their children.
    Node* traversePreviousNodePostOrder(const Node* stayWithin = 0) const;
    Node* traversePreviousSiblingPostOrder(const Node* stayWithin = 0) const;

    void checkSetPrefix(const AtomicString& prefix, ExceptionCode&);
    bool isDescendantOf(const Node*) const;
    bool contains(const Node*) const;
    bool containsIncludingShadowDOM(Node*);

    // This method is used to do strict error-checking when adding children via
    // the public DOM API (e.g., appendChild()).
    void checkAddChild(Node* newChild, ExceptionCode&); // Error-checking when adding via the DOM API

    void checkReplaceChild(Node* newChild, Node* oldChild, ExceptionCode&);
    virtual bool canReplaceChild(Node* newChild, Node* oldChild);
    
    // Used to determine whether range offsets use characters or node indices.
    virtual bool offsetInCharacters() const;
    // Number of DOM 16-bit units contained in node. Note that rendered text length can be different - e.g. because of
    // css-transform:capitalize breaking up precomposed characters and ligatures.
    virtual int maxCharacterOffset() const;

    // Whether or not a selection can be started in this object
    virtual bool canStartSelection() const;

    // Getting points into and out of screen space
    FloatPoint convertToPage(const FloatPoint&) const;
    FloatPoint convertFromPage(const FloatPoint&) const;

    // -----------------------------------------------------------------------------
    // Integration with rendering tree

    RenderObject* renderer() const { return m_renderer; }
    void setRenderer(RenderObject* renderer) { m_renderer = renderer; }
    
    // Use these two methods with caution.
    RenderBox* renderBox() const;
    RenderBoxModelObject* renderBoxModelObject() const;

    // Attaches this node to the rendering tree. This calculates the style to be applied to the node and creates an
    // appropriate RenderObject which will be inserted into the tree (except when the style has display: none). This
    // makes the node visible in the FrameView.
    virtual void attach();

    // Detaches the node from the rendering tree, making it invisible in the rendered view. This method will remove
    // the node's rendering object from the rendering tree and delete it.
    virtual void detach();

    void reattach();
    void reattachIfAttached();

    virtual void willRemove();
    void createRendererIfNeeded();
    virtual bool rendererIsNeeded(const NodeRenderingContext&);
    virtual bool childShouldCreateRenderer(Node*) const { return true; }
    virtual RenderObject* createRenderer(RenderArena*, RenderStyle*);
    ContainerNode* parentNodeForRenderingAndStyle();
    
    // Wrapper for nodes that don't have a renderer, but still cache the style (like HTMLOptionElement).
    RenderStyle* renderStyle() const;
    virtual void setRenderStyle(PassRefPtr<RenderStyle>);

    RenderStyle* computedStyle(PseudoId pseudoElementSpecifier = NOPSEUDO) { return virtualComputedStyle(pseudoElementSpecifier); }

    // -----------------------------------------------------------------------------
    // Notification of document structure changes

    // Notifies the node that it has been inserted into the document. This is called during document parsing, and also
    // when a node is added through the DOM methods insertBefore(), appendChild() or replaceChild(). Note that this only
    // happens when the node becomes part of the document tree, i.e. only when the document is actually an ancestor of
    // the node. The call happens _after_ the node has been added to the tree.
    //
    // This is similar to the DOMNodeInsertedIntoDocument DOM event, but does not require the overhead of event
    // dispatching.
    virtual void insertedIntoDocument();

    // Notifies the node that it is no longer part of the document tree, i.e. when the document is no longer an ancestor
    // node.
    //
    // This is similar to the DOMNodeRemovedFromDocument DOM event, but does not require the overhead of event
    // dispatching, and is called _after_ the node is removed from the tree.
    virtual void removedFromDocument();

    // These functions are called whenever you are connected or disconnected from a tree.  That tree may be the main
    // document tree, or it could be another disconnected tree.  Override these functions to do any work that depends
    // on connectedness to some ancestor (e.g., an ancestor <form> for example).
    virtual void insertedIntoTree(bool /*deep*/) { }
    virtual void removedFromTree(bool /*deep*/) { }

    // Notifies the node that it's list of children have changed (either by adding or removing child nodes), or a child
    // node that is of the type CDATA_SECTION_NODE, TEXT_NODE or COMMENT_NODE has changed its value.
    virtual void childrenChanged(bool /*changedByParser*/ = false, Node* /*beforeChange*/ = 0, Node* /*afterChange*/ = 0, int /*childCountDelta*/ = 0) { }

#ifndef NDEBUG
    virtual void formatForDebugger(char* buffer, unsigned length) const;

    void showNode(const char* prefix = "") const;
    void showTreeForThis() const;
    void showTreeAndMark(const Node* markedNode1, const char* markedLabel1, const Node* markedNode2 = 0, const char* markedLabel2 = 0) const;
    void showTreeForThisAcrossFrame() const;
#endif

    void registerDynamicSubtreeNodeList(DynamicSubtreeNodeList*);
    void unregisterDynamicSubtreeNodeList(DynamicSubtreeNodeList*);
    void invalidateNodeListsCacheAfterAttributeChanged(const QualifiedName&);
    void invalidateNodeListsCacheAfterChildrenChanged();
    void notifyLocalNodeListsLabelChanged();
    void removeCachedClassNodeList(ClassNodeList*, const String&);

    void removeCachedNameNodeList(NameNodeList*, const String&);
    void removeCachedTagNodeList(TagNodeList*, const AtomicString&);
    void removeCachedTagNodeList(TagNodeList*, const QualifiedName&);
    void removeCachedLabelsNodeList(DynamicSubtreeNodeList*);

    void removeCachedChildNodeList();

    PassRefPtr<NodeList> getElementsByTagName(const AtomicString&);
    PassRefPtr<NodeList> getElementsByTagNameNS(const AtomicString& namespaceURI, const AtomicString& localName);
    PassRefPtr<NodeList> getElementsByName(const String& elementName);
    PassRefPtr<NodeList> getElementsByClassName(const String& classNames);

    PassRefPtr<Element> querySelector(const String& selectors, ExceptionCode&);
    PassRefPtr<NodeList> querySelectorAll(const String& selectors, ExceptionCode&);

    unsigned short compareDocumentPosition(Node*);

    virtual Node* toNode();
    virtual HTMLInputElement* toInputElement();

    virtual const AtomicString& interfaceName() const;
    virtual ScriptExecutionContext* scriptExecutionContext() const;

    virtual bool addEventListener(const AtomicString& eventType, PassRefPtr<EventListener>, bool useCapture);
    virtual bool removeEventListener(const AtomicString& eventType, EventListener*, bool useCapture);

    // Handlers to do/undo actions on the target node before an event is dispatched to it and after the event
    // has been dispatched.  The data pointer is handed back by the preDispatch and passed to postDispatch.
    virtual void* preDispatchEventHandler(Event*) { return 0; }
    virtual void postDispatchEventHandler(Event*, void* /*dataFromPreDispatch*/) { }

    using EventTarget::dispatchEvent;
    bool dispatchEvent(PassRefPtr<Event>);
    void dispatchScopedEvent(PassRefPtr<Event>);
    void dispatchScopedEventDispatchMediator(PassRefPtr<EventDispatchMediator>);

    virtual void handleLocalEvents(Event*);

    void dispatchSubtreeModifiedEvent();
    void dispatchDOMActivateEvent(int detail, PassRefPtr<Event> underlyingEvent);
    void dispatchFocusInEvent(const AtomicString& eventType, PassRefPtr<Node> oldFocusedNode);
    void dispatchFocusOutEvent(const AtomicString& eventType, PassRefPtr<Node> newFocusedNode);

    bool dispatchKeyEvent(const PlatformKeyboardEvent&);
    bool dispatchWheelEvent(const PlatformWheelEvent&);
    bool dispatchMouseEvent(const PlatformMouseEvent&, const AtomicString& eventType, int clickCount = 0, Node* relatedTarget = 0);
    void dispatchSimulatedClick(PassRefPtr<Event> underlyingEvent, bool sendMouseEvents = false, bool showPressedLook = true);

    virtual void dispatchFocusEvent(PassRefPtr<Node> oldFocusedNode);
    virtual void dispatchBlurEvent(PassRefPtr<Node> newFocusedNode);
    virtual void dispatchChangeEvent();
    virtual void dispatchInputEvent();

    // Perform the default action for an event.
    virtual void defaultEventHandler(Event*);

    // Used for disabled form elements; if true, prevents mouse events from being dispatched
    // to event listeners, and prevents DOMActivate events from being sent at all.
    virtual bool disabled() const;

    using TreeShared<ContainerNode>::ref;
    using TreeShared<ContainerNode>::deref;

    virtual EventTargetData* eventTargetData();
    virtual EventTargetData* ensureEventTargetData();

#if ENABLE(MICRODATA)
    void itemTypeAttributeChanged();

    DOMSettableTokenList* itemProp();
    DOMSettableTokenList* itemRef();
    DOMSettableTokenList* itemType();
    HTMLPropertiesCollection* properties();
#endif

#if ENABLE(MUTATION_OBSERVERS)
    void getRegisteredMutationObserversOfType(HashMap<WebKitMutationObserver*, MutationRecordDeliveryOptions>&, WebKitMutationObserver::MutationType, const AtomicString& attributeName = nullAtom);
    MutationObserverRegistration* registerMutationObserver(PassRefPtr<WebKitMutationObserver>);
    void unregisterMutationObserver(MutationObserverRegistration*);
    void registerTransientMutationObserver(MutationObserverRegistration*);
    void unregisterTransientMutationObserver(MutationObserverRegistration*);
    void notifyMutationObserversNodeWillDetach();
#endif // ENABLE(MUTATION_OBSERVERS)

private:
    enum NodeFlags {
        IsTextFlag = 1,
        IsCommentFlag = 1 << 1,
        IsContainerFlag = 1 << 2,
        IsElementFlag = 1 << 3,
        IsStyledElementFlag = 1 << 4,
        IsHTMLFlag = 1 << 5,
        IsSVGFlag = 1 << 6,
        HasIDFlag = 1 << 7,
        HasClassFlag = 1 << 8,
        IsAttachedFlag = 1 << 9,
        ChildNeedsStyleRecalcFlag = 1 << 10,
        InDocumentFlag = 1 << 11,
        IsLinkFlag = 1 << 12,
        IsActiveFlag = 1 << 13,
        IsHoveredFlag = 1 << 14,
        InActiveChainFlag = 1 << 15,
        InDetachFlag = 1 << 16,
        HasRareDataFlag = 1 << 17,
        IsShadowRootOrSVGShadowRootFlag = 1 << 18,

        // These bits are used by derived classes, pulled up here so they can
        // be stored in the same memory word as the Node bits above.
        IsParsingChildrenFinishedFlag = 1 << 19, // Element
        IsStyleAttributeValidFlag = 1 << 20, // StyledElement
        IsSynchronizingStyleAttributeFlag = 1 << 21, // StyledElement
#if ENABLE(SVG)
        AreSVGAttributesValidFlag = 1 << 22, // Element
        IsSynchronizingSVGAttributesFlag = 1 << 23, // SVGElement
        HasSVGRareDataFlag = 1 << 24, // SVGElement
#endif

        StyleChangeMask = 1 << nodeStyleChangeShift | 1 << (nodeStyleChangeShift + 1),

        SelfOrAncestorHasDirAutoFlag = 1 << 27,
        HasCustomWillOrDidRecalcStyleFlag = 1 << 28,
        HasCustomStyleForRendererFlag = 1 << 29,

        HasNameFlag = 1 << 30,

#if ENABLE(SVG)
        DefaultNodeFlags = IsParsingChildrenFinishedFlag | IsStyleAttributeValidFlag | AreSVGAttributesValidFlag
#else
        DefaultNodeFlags = IsParsingChildrenFinishedFlag | IsStyleAttributeValidFlag
#endif
    };

    // 1 bit remaining

    bool getFlag(NodeFlags mask) const { return m_nodeFlags & mask; }
    void setFlag(bool f, NodeFlags mask) const { m_nodeFlags = (m_nodeFlags & ~mask) | (-(int32_t)f & mask); } 
    void setFlag(NodeFlags mask) const { m_nodeFlags |= mask; } 
    void clearFlag(NodeFlags mask) const { m_nodeFlags &= ~mask; } 

protected:
    enum ConstructionType { 
        CreateOther = DefaultNodeFlags,
        CreateText = DefaultNodeFlags | IsTextFlag,
        CreateComment = DefaultNodeFlags | IsCommentFlag,
        CreateContainer = DefaultNodeFlags | IsContainerFlag, 
        CreateElement = CreateContainer | IsElementFlag, 
        CreateShadowRoot = CreateContainer | IsShadowRootOrSVGShadowRootFlag,
        CreateStyledElement = CreateElement | IsStyledElementFlag, 
        CreateHTMLElement = CreateStyledElement | IsHTMLFlag, 
        CreateSVGElement = CreateStyledElement | IsSVGFlag,
        CreateSVGShadowRoot = CreateSVGElement | IsShadowRootOrSVGShadowRootFlag,
    };
    Node(Document*, ConstructionType);

    virtual void didMoveToNewDocument(Document* oldDocument);
    
    virtual void addSubresourceAttributeURLs(ListHashSet<KURL>&) const { }
    void setTabIndexExplicitly(short);
    void clearTabIndexExplicitly();
    
    bool hasRareData() const { return getFlag(HasRareDataFlag); }

    NodeRareData* rareData() const;
    NodeRareData* ensureRareData();
    void clearRareData();

    bool hasCustomWillOrDidRecalcStyle() const { return getFlag(HasCustomWillOrDidRecalcStyleFlag); }
    void setHasCustomWillOrDidRecalcStyle() { setFlag(true, HasCustomWillOrDidRecalcStyleFlag); }
    
    bool hasCustomStyleForRenderer() const { return getFlag(HasCustomStyleForRendererFlag); }
    void setHasCustomStyleForRenderer() { setFlag(true, HasCustomStyleForRendererFlag); }
    void clearHasCustomStyleForRenderer() { clearFlag(HasCustomStyleForRendererFlag); }

private:
    // These API should be only used for a tree scope migration.
    // setTreeScope() returns NodeRareData to save extra nodeRareData() invocations on the caller site.
    NodeRareData* setTreeScope(TreeScope*);
    void setDocument(Document*);

    enum EditableLevel { Editable, RichlyEditable };
    bool rendererIsEditable(EditableLevel) const;
    bool isEditableToAccessibility(EditableLevel) const;

    void setStyleChange(StyleChangeType);

    // Used to share code between lazyAttach and setNeedsStyleRecalc.
    void markAncestorsWithChildNeedsStyleRecalc();

    virtual void refEventTarget();
    virtual void derefEventTarget();

    virtual OwnPtr<NodeRareData> createRareData();
    bool rareDataFocused() const;

    virtual RenderStyle* nonRendererRenderStyle() const;

    virtual const AtomicString& virtualPrefix() const;
    virtual const AtomicString& virtualLocalName() const;
    virtual const AtomicString& virtualNamespaceURI() const;
    virtual RenderStyle* virtualComputedStyle(PseudoId = NOPSEUDO);

    Element* ancestorElement() const;

    // Use Node::parentNode as the consistent way of querying a parent node.
    // This method is made private to ensure a compiler error on call sites that
    // don't follow this rule.
    using TreeShared<ContainerNode>::parent;

    void trackForDebugging();

#if ENABLE(MUTATION_OBSERVERS)
    Vector<OwnPtr<MutationObserverRegistration> >* mutationObserverRegistry();
    HashSet<MutationObserverRegistration*>* transientMutationObserverRegistry();
    void collectMatchingObserversForMutation(HashMap<WebKitMutationObserver*, MutationRecordDeliveryOptions>&, Node* fromNode, WebKitMutationObserver::MutationType, const AtomicString& attributeName);
#endif

    mutable uint32_t m_nodeFlags;
    Document* m_document;
    Node* m_previous;
    Node* m_next;
    RenderObject* m_renderer;

protected:
    bool isParsingChildrenFinished() const { return getFlag(IsParsingChildrenFinishedFlag); }
    void setIsParsingChildrenFinished() { setFlag(IsParsingChildrenFinishedFlag); }
    void clearIsParsingChildrenFinished() { clearFlag(IsParsingChildrenFinishedFlag); }
    bool isStyleAttributeValid() const { return getFlag(IsStyleAttributeValidFlag); }
    void setIsStyleAttributeValid(bool f) { setFlag(f, IsStyleAttributeValidFlag); }
    void setIsStyleAttributeValid() const { setFlag(IsStyleAttributeValidFlag); }
    void clearIsStyleAttributeValid() { clearFlag(IsStyleAttributeValidFlag); }
    bool isSynchronizingStyleAttribute() const { return getFlag(IsSynchronizingStyleAttributeFlag); }
    void setIsSynchronizingStyleAttribute(bool f) { setFlag(f, IsSynchronizingStyleAttributeFlag); }
    void setIsSynchronizingStyleAttribute() const { setFlag(IsSynchronizingStyleAttributeFlag); }
    void clearIsSynchronizingStyleAttribute() const { clearFlag(IsSynchronizingStyleAttributeFlag); }

#if ENABLE(SVG)
    bool areSVGAttributesValid() const { return getFlag(AreSVGAttributesValidFlag); }
    void setAreSVGAttributesValid() const { setFlag(AreSVGAttributesValidFlag); }
    void clearAreSVGAttributesValid() { clearFlag(AreSVGAttributesValidFlag); }
    bool isSynchronizingSVGAttributes() const { return getFlag(IsSynchronizingSVGAttributesFlag); }
    void setIsSynchronizingSVGAttributes() const { setFlag(IsSynchronizingSVGAttributesFlag); }
    void clearIsSynchronizingSVGAttributes() const { clearFlag(IsSynchronizingSVGAttributesFlag); }
    bool hasRareSVGData() const { return getFlag(HasSVGRareDataFlag); }
    void setHasRareSVGData() { setFlag(HasSVGRareDataFlag); }
    void clearHasRareSVGData() { clearFlag(HasSVGRareDataFlag); }
#endif

#if ENABLE(MICRODATA)
    void setItemProp(const String&);
    void setItemRef(const String&);
    void setItemType(const String&);
#endif
};

// Used in Node::addSubresourceAttributeURLs() and in addSubresourceStyleURLs()
inline void addSubresourceURL(ListHashSet<KURL>& urls, const KURL& url)
{
    if (!url.isNull())
        urls.add(url);
}

inline ContainerNode* Node::parentNode() const
{
    return getFlag(IsShadowRootOrSVGShadowRootFlag) ? 0 : parent();
}

inline ContainerNode* Node::parentOrHostNode() const
{
    return parent();
}

inline ContainerNode* Node::parentNodeGuaranteedHostFree() const
{
    ASSERT(!getFlag(IsShadowRootOrSVGShadowRootFlag));
    return parentOrHostNode();
}

inline void Node::reattach()
{
    if (attached())
        detach();
    attach();
}

inline void Node::reattachIfAttached()
{
    if (attached())
        reattach();
}

} //namespace

#ifndef NDEBUG
// Outside the WebCore namespace for ease of invocation from gdb.
void showTree(const WebCore::Node*);
#endif

#endif
