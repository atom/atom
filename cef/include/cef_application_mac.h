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

#ifndef _CEF_APPLICATION_MAC_H
#define _CEF_APPLICATION_MAC_H
#pragma once

#include "cef.h"

#if defined(OS_MACOSX) && defined(__OBJC__)

#ifdef BUILDING_CEF_SHARED

// Use the existing CrAppProtocol definition.
#include "base/message_pump_mac.h"

// Use the existing empty protocol definitions.
#import "base/mac/cocoa_protocols.h"

#else // BUILDING_CEF_SHARED

#import <AppKit/AppKit.h>
#import <Cocoa/Cocoa.h>

// Copy of CrAppProtocol definition from base/message_pump_mac.h.
@protocol CrAppProtocol
// Must return true if -[NSApplication sendEvent:] is currently on the stack.
- (BOOL)isHandlingSendEvent;
@end

// The Mac OS X 10.6 SDK introduced new protocols used for delegates.  These
// protocol defintions were not present in earlier releases of the Mac OS X
// SDK.  In order to support building against the new SDK, which requires
// delegates to conform to these protocols, and earlier SDKs, which do not
// define these protocols at all, this file will provide empty protocol
// definitions when used with earlier SDK versions.

#if !defined(MAC_OS_X_VERSION_10_6) || \
MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_6

#define DEFINE_EMPTY_PROTOCOL(p) \
@protocol p \
@end

DEFINE_EMPTY_PROTOCOL(NSAlertDelegate)
DEFINE_EMPTY_PROTOCOL(NSApplicationDelegate)
DEFINE_EMPTY_PROTOCOL(NSControlTextEditingDelegate)
DEFINE_EMPTY_PROTOCOL(NSMatrixDelegate)
DEFINE_EMPTY_PROTOCOL(NSMenuDelegate)
DEFINE_EMPTY_PROTOCOL(NSOpenSavePanelDelegate)
DEFINE_EMPTY_PROTOCOL(NSOutlineViewDataSource)
DEFINE_EMPTY_PROTOCOL(NSOutlineViewDelegate)
DEFINE_EMPTY_PROTOCOL(NSSpeechSynthesizerDelegate)
DEFINE_EMPTY_PROTOCOL(NSSplitViewDelegate)
DEFINE_EMPTY_PROTOCOL(NSTableViewDataSource)
DEFINE_EMPTY_PROTOCOL(NSTableViewDelegate)
DEFINE_EMPTY_PROTOCOL(NSTextFieldDelegate)
DEFINE_EMPTY_PROTOCOL(NSTextViewDelegate)
DEFINE_EMPTY_PROTOCOL(NSWindowDelegate)

#undef DEFINE_EMPTY_PROTOCOL

#endif

#endif // BUILDING_CEF_SHARED

// All CEF client applications must subclass NSApplication and implement this
// protocol.
@protocol CefAppProtocol<CrAppProtocol>
- (void)setHandlingSendEvent:(BOOL)handlingSendEvent;
@end

// Controls the state of |isHandlingSendEvent| in the event loop so that it is
// reset properly.
class CefScopedSendingEvent {
public:
  CefScopedSendingEvent()
    : app_(static_cast<NSApplication<CefAppProtocol>*>(
              [NSApplication sharedApplication])),
      handling_([app_ isHandlingSendEvent]) {
    [app_ setHandlingSendEvent:YES];
  }
  ~CefScopedSendingEvent() {
    [app_ setHandlingSendEvent:handling_];
  }
  
private:
  NSApplication<CefAppProtocol>* app_;
  BOOL handling_;
};

#endif  // defined(OS_MACOSX) && defined(__OBJC__)

#endif // _CEF_APPLICATION_MAC_H
