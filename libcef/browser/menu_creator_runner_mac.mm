// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "libcef/browser/menu_creator_runner_mac.h"
#include "libcef/browser/browser_host_impl.h"

#include "base/message_loop.h"
#include "base/compiler_specific.h"
#import "base/mac/scoped_sending_event.h"
#import "chrome/browser/ui/cocoa/menu_controller.h"
#include "content/public/browser/web_contents_view.h"

CefMenuCreatorRunnerMac::CefMenuCreatorRunnerMac()
    : menu_controller_(nil) {
}

CefMenuCreatorRunnerMac::~CefMenuCreatorRunnerMac() {
  if (menu_controller_ != nil)
    [menu_controller_ release];
}

bool CefMenuCreatorRunnerMac::RunContextMenu(CefMenuCreator* manager) {
  // Create a menu controller based on the model.
  if (menu_controller_ != nil)
    [menu_controller_ release];
  menu_controller_ =
      [[MenuController alloc] initWithModel:manager->model()
                     useWithPopUpButtonCell:NO];

  NSView* parent_view =
      manager->browser()->GetWebContents()->GetContentNativeView();

  // Synthesize an event for the click, as there is no certainty that
  // [NSApp currentEvent] will return a valid event.
  NSEvent* currentEvent = [NSApp currentEvent];
  NSWindow* window = [parent_view window];
  NSPoint position = [window mouseLocationOutsideOfEventStream];
  NSTimeInterval eventTime = [currentEvent timestamp];
  NSEvent* clickEvent = [NSEvent mouseEventWithType:NSRightMouseDown
                                           location:position
                                      modifierFlags:NSRightMouseDownMask
                                          timestamp:eventTime
                                       windowNumber:[window windowNumber]
                                            context:nil
                                        eventNumber:0
                                         clickCount:1
                                           pressure:1.0];

  {
    // Make sure events can be pumped while the menu is up.
    MessageLoop::ScopedNestableTaskAllower allow(MessageLoop::current());

    // One of the events that could be pumped is |window.close()|.
    // User-initiated event-tracking loops protect against this by
    // setting flags in -[CrApplication sendEvent:], but since
    // web-content menus are initiated by IPC message the setup has to
    // be done manually.
    base::mac::ScopedSendingEvent sendingEventScoper;

    // Show the menu. Blocks until the menu is dismissed.
    [NSMenu popUpContextMenu:[menu_controller_ menu]
                   withEvent:clickEvent
                     forView:parent_view];
  }

  return true;
}
