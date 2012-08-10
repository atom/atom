// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/application_mac.h"

#include "base/message_pump_mac.h"
#include "base/mac/scoped_sending_event.h"

@interface CefCrApplication : NSApplication<CrAppProtocol,
                                            CrAppControlProtocol> {
 @private
  BOOL handlingSendEvent_;
}

// CrAppProtocol:
- (BOOL)isHandlingSendEvent;

// CrAppControlProtocol:
- (void)setHandlingSendEvent:(BOOL)handlingSendEvent;

@end

@implementation CefCrApplication

- (BOOL)isHandlingSendEvent {
  return handlingSendEvent_;
}

- (void)sendEvent:(NSEvent*)event {
  BOOL wasHandlingSendEvent = handlingSendEvent_;
  handlingSendEvent_ = YES;
  [super sendEvent:event];
  handlingSendEvent_ = wasHandlingSendEvent;
}

- (void)setHandlingSendEvent:(BOOL)handlingSendEvent {
  handlingSendEvent_ = handlingSendEvent;
}

@end

void CefCrApplicationCreate() {
  [CefCrApplication sharedApplication];
}
