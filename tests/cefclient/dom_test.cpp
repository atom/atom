// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "cefclient/dom_test.h"

#include <sstream>
#include <string>

#include "include/cef_dom.h"
#include "cefclient/util.h"

namespace dom_test {

const char kTestUrl[] = "http://tests/domaccess";

namespace {

const char* kMessageName = "DOMTest.Message";

class ClientDOMEventListener : public CefDOMEventListener {
 public:
  ClientDOMEventListener() {
  }

  virtual void HandleEvent(CefRefPtr<CefDOMEvent> event) OVERRIDE {
    CefRefPtr<CefDOMDocument> document = event->GetDocument();
    ASSERT(document.get());

    std::stringstream ss;

    CefRefPtr<CefDOMNode> button = event->GetTarget();
    ASSERT(button.get());
    std::string buttonValue = button->GetElementAttribute("value");
    ss << "You clicked the " << buttonValue.c_str() << " button. ";

    if (document->HasSelection()) {
      std::string startName, endName;

      // Determine the start name by first trying to locate the "id" attribute
      // and then defaulting to the tag name.
      {
        CefRefPtr<CefDOMNode> node = document->GetSelectionStartNode();
        if (!node->IsElement())
          node = node->GetParent();
        if (node->IsElement() && node->HasElementAttribute("id"))
          startName = node->GetElementAttribute("id");
        else
          startName = node->GetName();
      }

      // Determine the end name by first trying to locate the "id" attribute
      // and then defaulting to the tag name.
      {
        CefRefPtr<CefDOMNode> node = document->GetSelectionEndNode();
        if (!node->IsElement())
          node = node->GetParent();
        if (node->IsElement() && node->HasElementAttribute("id"))
          endName = node->GetElementAttribute("id");
        else
          endName = node->GetName();
      }

      ss << "The selection is from " <<
          startName.c_str() << ":" << document->GetSelectionStartOffset() <<
          " to " <<
          endName.c_str() << ":" << document->GetSelectionEndOffset();
    } else {
      ss << "Nothing is selected.";
    }

    // Update the description.
    CefRefPtr<CefDOMNode> desc = document->GetElementById("description");
    ASSERT(desc.get());
    CefRefPtr<CefDOMNode> text = desc->GetFirstChild();
    ASSERT(text.get());
    ASSERT(text->IsText());
    text->SetValue(ss.str());
  }

  IMPLEMENT_REFCOUNTING(ClientDOMEventListener);
};

class ClientDOMVisitor : public CefDOMVisitor {
 public:
  ClientDOMVisitor() {
  }

  virtual void Visit(CefRefPtr<CefDOMDocument> document) OVERRIDE {
    // Register a click listener for the button.
    CefRefPtr<CefDOMNode> button = document->GetElementById("button");
    ASSERT(button.get());
    button->AddEventListener("click", new ClientDOMEventListener(), false);
  }

  IMPLEMENT_REFCOUNTING(ClientDOMVisitor);
};

class DOMRenderDelegate : public ClientApp::RenderDelegate {
 public:
  DOMRenderDelegate() {
  }

  virtual bool OnProcessMessageReceived(
      CefRefPtr<ClientApp> app,
      CefRefPtr<CefBrowser> browser,
      CefProcessId source_process,
      CefRefPtr<CefProcessMessage> message) OVERRIDE {
    if (message->GetName() == kMessageName) {
      // Visit the DOM to attach the event listener.
      browser->GetMainFrame()->VisitDOM(new ClientDOMVisitor);
      return true;
    }

    return false;
  }

 private:
  IMPLEMENT_REFCOUNTING(DOMRenderDelegate);
};

}  // namespace

void CreateRenderDelegates(ClientApp::RenderDelegateSet& delegates) {
  delegates.insert(new DOMRenderDelegate);
}

void RunTest(CefRefPtr<CefBrowser> browser) {
  // Load the test URL.
  browser->GetMainFrame()->LoadURL(kTestUrl);
}

void OnLoadEnd(CefRefPtr<CefBrowser> browser) {
  // Send a message to the render process to continue the test setup.
  browser->SendProcessMessage(PID_RENDERER,
      CefProcessMessage::Create(kMessageName));
}

}  // namespace dom_test
