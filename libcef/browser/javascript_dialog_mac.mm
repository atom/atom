// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/javascript_dialog.h"
#include "libcef/browser/javascript_dialog_creator.h"

#import <Cocoa/Cocoa.h>

#import "base/mac/cocoa_protocols.h"
#import "base/memory/scoped_nsobject.h"
#include "base/sys_string_conversions.h"
#include "base/utf_string_conversions.h"

// Helper object that receives the notification that the dialog/sheet is
// going away. Is responsible for cleaning itself up.
@interface CefJavaScriptDialogHelper : NSObject<NSAlertDelegate> {
 @private
  scoped_nsobject<NSAlert> alert_;
  NSTextField* textField_;  // WEAK; owned by alert_

  // Copies of the fields in CefJavaScriptDialog because they're private.
  CefJavaScriptDialogCreator* creator_;
  content::JavaScriptDialogCreator::DialogClosedCallback callback_;
}

- (id)initHelperWithCreator:(CefJavaScriptDialogCreator*)creator
   andCallback:(content::JavaScriptDialogCreator::DialogClosedCallback)callback;
- (NSAlert*)alert;
- (NSTextField*)textField;
- (void)alertDidEnd:(NSAlert*)alert
         returnCode:(int)returnCode
        contextInfo:(void*)contextInfo;
- (void)cancel;

@end

@implementation CefJavaScriptDialogHelper

- (id)initHelperWithCreator:(CefJavaScriptDialogCreator*)creator
  andCallback:(content::JavaScriptDialogCreator::DialogClosedCallback)callback {
  if (self = [super init]) {
    creator_ = creator;
    callback_ = callback;
  }

  return self;
}

- (NSAlert*)alert {
  alert_.reset([[NSAlert alloc] init]);
  return alert_;
}

- (NSTextField*)textField {
  textField_ = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 22)];
  [[textField_ cell] setLineBreakMode:NSLineBreakByTruncatingTail];
  [alert_ setAccessoryView:textField_];
  [textField_ release];

  return textField_;
}

- (void)alertDidEnd:(NSAlert*)alert
         returnCode:(int)returnCode
        contextInfo:(void*)contextInfo {
  if (returnCode == NSRunStoppedResponse)
    return;

  bool success = returnCode == NSAlertFirstButtonReturn;
  string16 input;
  if (textField_)
    input = base::SysNSStringToUTF16([textField_ stringValue]);

  CefJavaScriptDialog* native_dialog =
      reinterpret_cast<CefJavaScriptDialog*>(contextInfo);
  callback_.Run(success, input);
  creator_->DialogClosed(native_dialog);
}

- (void)cancel {
  [NSApp endSheet:[alert_ window]];
  alert_.reset();
}

@end

CefJavaScriptDialog::CefJavaScriptDialog(
    CefJavaScriptDialogCreator* creator,
    content::JavaScriptMessageType message_type,
    const string16& display_url,
    const string16& message_text,
    const string16& default_prompt_text,
    const content::JavaScriptDialogCreator::DialogClosedCallback& callback)
    : creator_(creator),
      callback_(callback) {
  bool text_field =
      message_type == content::JAVASCRIPT_MESSAGE_TYPE_PROMPT;
  bool one_button =
      message_type == content::JAVASCRIPT_MESSAGE_TYPE_ALERT;

  helper_ =
      [[CefJavaScriptDialogHelper alloc] initHelperWithCreator:creator
                                                   andCallback:callback];

  // Show the modal dialog.
  NSAlert* alert = [helper_ alert];
  NSTextField* field = nil;
  if (text_field) {
    field = [helper_ textField];
    [field setStringValue:base::SysUTF16ToNSString(default_prompt_text)];
  }
  [alert setDelegate:helper_];
  [alert setInformativeText:base::SysUTF16ToNSString(message_text)];

  string16 label;
  switch (message_type) {
    case content::JAVASCRIPT_MESSAGE_TYPE_ALERT:
      label = ASCIIToUTF16("JavaScript Alert");
      break;
    case content::JAVASCRIPT_MESSAGE_TYPE_PROMPT:
      label = ASCIIToUTF16("JavaScript Prompt");
      break;
    case content::JAVASCRIPT_MESSAGE_TYPE_CONFIRM:
      label = ASCIIToUTF16("JavaScript Confirm");
      break;
  }
  if (!display_url.empty())
    label += ASCIIToUTF16(" - ") + display_url;

  [alert setMessageText:base::SysUTF16ToNSString(label)];

  [alert addButtonWithTitle:@"OK"];
  if (!one_button) {
    NSButton* other = [alert addButtonWithTitle:@"Cancel"];
    [other setKeyEquivalent:@"\e"];
  }

  [alert
      beginSheetModalForWindow:nil  // nil here makes it app-modal
                 modalDelegate:helper_
                didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                   contextInfo:this];

  if ([alert accessoryView])
    [[alert window] makeFirstResponder:[alert accessoryView]];
}

CefJavaScriptDialog::~CefJavaScriptDialog() {
  [helper_ release];
}

void CefJavaScriptDialog::Cancel() {
  [helper_ cancel];
}
