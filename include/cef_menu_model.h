// Copyright (c) 2012 Marshall A. Greenblatt. All rights reserved.
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

#ifndef CEF_INCLUDE_CEF_MENU_MODEL_H_
#define CEF_INCLUDE_CEF_MENU_MODEL_H_
#pragma once

#include "include/cef_base.h"

///
// Supports creation and modification of menus. See cef_menu_id_t for the
// command ids that have default implementations. All user-defined command ids
// should be between MENU_ID_USER_FIRST and MENU_ID_USER_LAST. The methods of
// this class can only be accessed on the browser process the UI thread.
///
/*--cef(source=library)--*/
class CefMenuModel : public virtual CefBase {
 public:
  typedef cef_menu_item_type_t MenuItemType;

  ///
  // Clears the menu. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool Clear() =0;

  ///
  // Returns the number of items in this menu.
  ///
  /*--cef()--*/
  virtual int GetCount() =0;

  //
  // Add a separator to the menu. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool AddSeparator() =0;

  //
  // Add an item to the menu. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool AddItem(int command_id,
                       const CefString& label) =0;

  //
  // Add a check item to the menu. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool AddCheckItem(int command_id,
                            const CefString& label) =0;
  //
  // Add a radio item to the menu. Only a single item with the specified
  // |group_id| can be checked at a time. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool AddRadioItem(int command_id,
                            const CefString& label,
                            int group_id) =0;

  //
  // Add a sub-menu to the menu. The new sub-menu is returned.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefMenuModel> AddSubMenu(int command_id,
                                             const CefString& label) =0;

  //
  // Insert a separator in the menu at the specified |index|. Returns true on
  // success.
  ///
  /*--cef()--*/
  virtual bool InsertSeparatorAt(int index) =0;

  //
  // Insert an item in the menu at the specified |index|. Returns true on
  // success.
  ///
  /*--cef()--*/
  virtual bool InsertItemAt(int index,
                            int command_id,
                            const CefString& label) =0;

  //
  // Insert a check item in the menu at the specified |index|. Returns true on
  // success.
  ///
  /*--cef()--*/
  virtual bool InsertCheckItemAt(int index,
                                 int command_id,
                                 const CefString& label) =0;

  //
  // Insert a radio item in the menu at the specified |index|. Only a single
  // item with the specified |group_id| can be checked at a time. Returns true
  // on success.
  ///
  /*--cef()--*/
  virtual bool InsertRadioItemAt(int index,
                                 int command_id,
                                 const CefString& label,
                                 int group_id) =0;

  //
  // Insert a sub-menu in the menu at the specified |index|. The new sub-menu
  // is returned.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefMenuModel> InsertSubMenuAt(int index,
                                                  int command_id,
                                                  const CefString& label) =0;

  ///
  // Removes the item with the specified |command_id|. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool Remove(int command_id) =0;

  ///
  // Removes the item at the specified |index|. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool RemoveAt(int index) =0;

  ///
  // Returns the index associated with the specified |command_id| or -1 if not
  // found due to the command id not existing in the menu.
  ///
  /*--cef()--*/
  virtual int GetIndexOf(int command_id) =0;

  ///
  // Returns the command id at the specified |index| or -1 if not found due to
  // invalid range or the index being a separator.
  ///
  /*--cef()--*/
  virtual int GetCommandIdAt(int index) =0;

  ///
  // Sets the command id at the specified |index|. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool SetCommandIdAt(int index, int command_id) =0;

  ///
  // Returns the label for the specified |command_id| or empty if not found.
  ///
  /*--cef()--*/
  virtual CefString GetLabel(int command_id) =0;

  ///
  // Returns the label at the specified |index| or empty if not found due to
  // invalid range or the index being a separator.
  ///
  /*--cef()--*/
  virtual CefString GetLabelAt(int index) =0;

  ///
  // Sets the label for the specified |command_id|. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool SetLabel(int command_id, const CefString& label) =0;

  ///
  // Set the label at the specified |index|. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool SetLabelAt(int index, const CefString& label) =0;

  ///
  // Returns the item type for the specified |command_id|.
  ///
  /*--cef(default_retval=MENUITEMTYPE_NONE)--*/
  virtual MenuItemType GetType(int command_id) =0;

  ///
  // Returns the item type at the specified |index|.
  ///
  /*--cef(default_retval=MENUITEMTYPE_NONE)--*/
  virtual MenuItemType GetTypeAt(int index) =0;

  ///
  // Returns the group id for the specified |command_id| or -1 if invalid.
  ///
  /*--cef()--*/
  virtual int GetGroupId(int command_id) =0;

  ///
  // Returns the group id at the specified |index| or -1 if invalid.
  ///
  /*--cef()--*/
  virtual int GetGroupIdAt(int index) =0;

  ///
  // Sets the group id for the specified |command_id|. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool SetGroupId(int command_id, int group_id) =0;

  ///
  // Sets the group id at the specified |index|. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool SetGroupIdAt(int index, int group_id) =0;

  ///
  // Returns the submenu for the specified |command_id| or empty if invalid.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefMenuModel> GetSubMenu(int command_id) =0;

  ///
  // Returns the submenu at the specified |index| or empty if invalid.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefMenuModel> GetSubMenuAt(int index) =0;

  //
  // Returns true if the specified |command_id| is visible.
  ///
  /*--cef()--*/
  virtual bool IsVisible(int command_id) =0;

  //
  // Returns true if the specified |index| is visible.
  ///
  /*--cef()--*/
  virtual bool IsVisibleAt(int index) =0;

  //
  // Change the visibility of the specified |command_id|. Returns true on
  // success.
  ///
  /*--cef()--*/
  virtual bool SetVisible(int command_id, bool visible) =0;

  //
  // Change the visibility at the specified |index|. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool SetVisibleAt(int index, bool visible) =0;

  //
  // Returns true if the specified |command_id| is enabled.
  ///
  /*--cef()--*/
  virtual bool IsEnabled(int command_id) =0;

  //
  // Returns true if the specified |index| is enabled.
  ///
  /*--cef()--*/
  virtual bool IsEnabledAt(int index) =0;

  //
  // Change the enabled status of the specified |command_id|. Returns true on
  // success.
  ///
  /*--cef()--*/
  virtual bool SetEnabled(int command_id, bool enabled) =0;

  //
  // Change the enabled status at the specified |index|. Returns true on
  // success.
  ///
  /*--cef()--*/
  virtual bool SetEnabledAt(int index, bool enabled) =0;

  //
  // Returns true if the specified |command_id| is checked. Only applies to
  // check and radio items.
  ///
  /*--cef()--*/
  virtual bool IsChecked(int command_id) =0;

  //
  // Returns true if the specified |index| is checked. Only applies to check
  // and radio items.
  ///
  /*--cef()--*/
  virtual bool IsCheckedAt(int index) =0;

  //
  // Check the specified |command_id|. Only applies to check and radio items.
  // Returns true on success.
  ///
  /*--cef()--*/
  virtual bool SetChecked(int command_id, bool checked) =0;

  //
  // Check the specified |index|. Only applies to check and radio items. Returns
  // true on success.
  ///
  /*--cef()--*/
  virtual bool SetCheckedAt(int index, bool checked) =0;

  //
  // Returns true if the specified |command_id| has a keyboard accelerator
  // assigned.
  ///
  /*--cef()--*/
  virtual bool HasAccelerator(int command_id) =0;

  //
  // Returns true if the specified |index| has a keyboard accelerator assigned.
  ///
  /*--cef()--*/
  virtual bool HasAcceleratorAt(int index) =0;

  //
  // Set the keyboard accelerator for the specified |command_id|. |key_code| can
  // be any virtual key or character value. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool SetAccelerator(int command_id,
                              int key_code,
                              bool shift_pressed,
                              bool ctrl_pressed,
                              bool alt_pressed) =0;

  //
  // Set the keyboard accelerator at the specified |index|. |key_code| can be
  // any virtual key or character value. Returns true on success.
  ///
  /*--cef()--*/
  virtual bool SetAcceleratorAt(int index,
                                int key_code,
                                bool shift_pressed,
                                bool ctrl_pressed,
                                bool alt_pressed) =0;

  //
  // Remove the keyboard accelerator for the specified |command_id|. Returns
  // true on success.
  ///
  /*--cef()--*/
  virtual bool RemoveAccelerator(int command_id) =0;

  //
  // Remove the keyboard accelerator at the specified |index|. Returns true on
  // success.
  ///
  /*--cef()--*/
  virtual bool RemoveAcceleratorAt(int index) =0;

  //
  // Retrieves the keyboard accelerator for the specified |command_id|. Returns
  // true on success.
  ///
  /*--cef()--*/
  virtual bool GetAccelerator(int command_id,
                              int& key_code,
                              bool& shift_pressed,
                              bool& ctrl_pressed,
                              bool& alt_pressed) =0;

  //
  // Retrieves the keyboard accelerator for the specified |index|. Returns true
  // on success.
  ///
  /*--cef()--*/
  virtual bool GetAcceleratorAt(int index,
                                int& key_code,
                                bool& shift_pressed,
                                bool& ctrl_pressed,
                                bool& alt_pressed) =0;
};

#endif  // CEF_INCLUDE_CEF_MENU_MODEL_H_
