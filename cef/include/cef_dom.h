// Copyright (c) 2011 Marshall A. Greenblatt. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//    * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//    * Neither the name of Google Inc. nor the name Chromium Embedded
// Framework nor the names of its contributors may be used to endorse
// or promote products derived from this software without specific prior
// written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// ---------------------------------------------------------------------------
//
// The contents of this file must follow a specific format in order to
// support the CEF translator tool. See the translator.README.txt file in the
// tools directory for more information.
//

#ifndef CEF_INCLUDE_CEF_DOM_H_
#define CEF_INCLUDE_CEF_DOM_H_
#pragma once

#include "include/cef_base.h"
#include <map>

class CefDOMDocument;
class CefDOMEventListener;
class CefDOMNode;

///
// Interface to implement for visiting the DOM. The methods of this class will
// be called on the UI thread.
///
/*--cef(source=client)--*/
class CefDOMVisitor : public virtual CefBase {
 public:
  ///
  // Method executed for visiting the DOM. The document object passed to this
  // method represents a snapshot of the DOM at the time this method is
  // executed. DOM objects are only valid for the scope of this method. Do not
  // keep references to or attempt to access any DOM objects outside the scope
  // of this method.
  ///
  /*--cef()--*/
  virtual void Visit(CefRefPtr<CefDOMDocument> document) =0;
};


///
// Class used to represent a DOM document. The methods of this class should only
// be called on the UI thread.
///
/*--cef(source=library)--*/
class CefDOMDocument : public virtual CefBase {
 public:
  typedef cef_dom_document_type_t Type;

  ///
  // Returns the document type.
  ///
  /*--cef(default_retval=DOM_DOCUMENT_TYPE_UNKNOWN)--*/
  virtual Type GetType() =0;

  ///
  // Returns the root document node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetDocument() =0;

  ///
  // Returns the BODY node of an HTML document.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetBody() =0;

  ///
  // Returns the HEAD node of an HTML document.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetHead() =0;

  ///
  // Returns the title of an HTML document.
  ///
  /*--cef()--*/
  virtual CefString GetTitle() =0;

  ///
  // Returns the document element with the specified ID value.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetElementById(const CefString& id) =0;

  ///
  // Returns the node that currently has keyboard focus.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetFocusedNode() =0;

  ///
  // Returns true if a portion of the document is selected.
  ///
  /*--cef()--*/
  virtual bool HasSelection() =0;

  ///
  // Returns the selection start node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetSelectionStartNode() =0;

  ///
  // Returns the selection offset within the start node.
  ///
  /*--cef()--*/
  virtual int GetSelectionStartOffset() =0;

  ///
  // Returns the selection end node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetSelectionEndNode() =0;

  ///
  // Returns the selection offset within the end node.
  ///
  /*--cef()--*/
  virtual int GetSelectionEndOffset() =0;

  ///
  // Returns the contents of this selection as markup.
  ///
  /*--cef()--*/
  virtual CefString GetSelectionAsMarkup() =0;

  ///
  // Returns the contents of this selection as text.
  ///
  /*--cef()--*/
  virtual CefString GetSelectionAsText() =0;

  ///
  // Returns the base URL for the document.
  ///
  /*--cef()--*/
  virtual CefString GetBaseURL() =0;

  ///
  // Returns a complete URL based on the document base URL and the specified
  // partial URL.
  ///
  /*--cef()--*/
  virtual CefString GetCompleteURL(const CefString& partialURL) =0;
};


///
// Class used to represent a DOM node. The methods of this class should only be
// called on the UI thread.
///
/*--cef(source=library)--*/
class CefDOMNode : public virtual CefBase {
 public:
  typedef std::map<CefString, CefString> AttributeMap;
  typedef cef_dom_node_type_t Type;

  ///
  // Returns the type for this node.
  ///
  /*--cef(default_retval=DOM_NODE_TYPE_UNSUPPORTED)--*/
  virtual Type GetType() =0;

  ///
  // Returns true if this is a text node.
  ///
  /*--cef()--*/
  virtual bool IsText() =0;

  ///
  // Returns true if this is an element node.
  ///
  /*--cef()--*/
  virtual bool IsElement() =0;

  ///
  // Returns true if this is a form control element node.
  ///
  /*--cef()--*/
  virtual bool IsFormControlElement() =0;

  ///
  // Returns the type of this form control element node.
  ///
  /*--cef()--*/
  virtual CefString GetFormControlElementType() =0;

  ///
  // Returns true if this object is pointing to the same handle as |that|
  // object.
  ///
  /*--cef()--*/
  virtual bool IsSame(CefRefPtr<CefDOMNode> that) =0;

  ///
  // Returns the name of this node.
  ///
  /*--cef()--*/
  virtual CefString GetName() =0;

  ///
  // Returns the value of this node.
  ///
  /*--cef()--*/
  virtual CefString GetValue() =0;

  ///
  // Set the value of this node. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool SetValue(const CefString& value) =0;

  ///
  // Returns the contents of this node as markup.
  ///
  /*--cef()--*/
  virtual CefString GetAsMarkup() =0;

  ///
  // Returns the document associated with this node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMDocument> GetDocument() =0;

  ///
  // Returns the parent node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetParent() =0;

  ///
  // Returns the previous sibling node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetPreviousSibling() =0;

  ///
  // Returns the next sibling node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetNextSibling() =0;

  ///
  // Returns true if this node has child nodes.
  ///
  /*--cef()--*/
  virtual bool HasChildren() =0;

  ///
  // Return the first child node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetFirstChild() =0;

  ///
  // Returns the last child node.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetLastChild() =0;

  ///
  // Add an event listener to this node for the specified event type. If
  // |useCapture| is true then this listener will be considered a capturing
  // listener. Capturing listeners will recieve all events of the specified
  // type before the events are dispatched to any other event targets beneath
  // the current node in the tree. Events which are bubbling upwards through
  // the tree will not trigger a capturing listener. Separate calls to this
  // method can be used to register the same listener with and without capture.
  // See WebCore/dom/EventNames.h for the list of supported event types.
  ///
  /*--cef()--*/
  virtual void AddEventListener(const CefString& eventType,
                                CefRefPtr<CefDOMEventListener> listener,
                                bool useCapture) =0;


  // The following methods are valid only for element nodes.

  ///
  // Returns the tag name of this element.
  ///
  /*--cef()--*/
  virtual CefString GetElementTagName() =0;

  ///
  // Returns true if this element has attributes.
  ///
  /*--cef()--*/
  virtual bool HasElementAttributes() =0;

  ///
  // Returns true if this element has an attribute named |attrName|.
  ///
  /*--cef()--*/
  virtual bool HasElementAttribute(const CefString& attrName) =0;

  ///
  // Returns the element attribute named |attrName|.
  ///
  /*--cef()--*/
  virtual CefString GetElementAttribute(const CefString& attrName) =0;

  ///
  // Returns a map of all element attributes.
  ///
  /*--cef()--*/
  virtual void GetElementAttributes(AttributeMap& attrMap) =0;

  ///
  // Set the value for the element attribute named |attrName|. Returns true on
  // success.
  ///
  /*--cef()--*/
  virtual bool SetElementAttribute(const CefString& attrName,
                                   const CefString& value) =0;

  ///
  // Returns the inner text of the element.
  ///
  /*--cef()--*/
  virtual CefString GetElementInnerText() =0;
};


///
// Class used to represent a DOM event. The methods of this class should only
// be called on the UI thread.
///
/*--cef(source=library)--*/
class CefDOMEvent : public virtual CefBase {
 public:
  typedef cef_dom_event_category_t Category;
  typedef cef_dom_event_phase_t Phase;

  ///
  // Returns the event type.
  ///
  /*--cef()--*/
  virtual CefString GetType() =0;

  ///
  // Returns the event category.
  ///
  /*--cef(default_retval=DOM_EVENT_CATEGORY_UNKNOWN)--*/
  virtual Category GetCategory() =0;

  ///
  // Returns the event processing phase.
  ///
  /*--cef(default_retval=DOM_EVENT_PHASE_UNKNOWN)--*/
  virtual Phase GetPhase() =0;

  ///
  // Returns true if the event can bubble up the tree.
  ///
  /*--cef()--*/
  virtual bool CanBubble() =0;

  ///
  // Returns true if the event can be canceled.
  ///
  /*--cef()--*/
  virtual bool CanCancel() =0;

  ///
  // Returns the document associated with this event.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMDocument> GetDocument() =0;

  ///
  // Returns the target of the event.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetTarget() =0;

  ///
  // Returns the current target of the event.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefDOMNode> GetCurrentTarget() =0;
};


///
// Interface to implement for handling DOM events. The methods of this class
// will be called on the UI thread.
///
/*--cef(source=client)--*/
class CefDOMEventListener : public virtual CefBase {
 public:
  ///
  // Called when an event is received. The event object passed to this method
  // contains a snapshot of the DOM at the time this method is executed. DOM
  // objects are only valid for the scope of this method. Do not keep references
  // to or attempt to access any DOM objects outside the scope of this method.
  ///
  /*--cef()--*/
  virtual void HandleEvent(CefRefPtr<CefDOMEvent> event) =0;
};

#endif  // CEF_INCLUDE_CEF_DOM_H_
