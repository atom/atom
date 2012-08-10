// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef CEF_LIBCEF_BROWSER_MENU_MODEL_IMPL_H_
#define CEF_LIBCEF_BROWSER_MENU_MODEL_IMPL_H_
#pragma once

#include <vector>

#include "include/cef_menu_model.h"

#include "base/memory/scoped_ptr.h"
#include "base/threading/platform_thread.h"
#include "ui/base/models/menu_model.h"

class CefMenuModelImpl : public CefMenuModel {
 public:
  class Delegate {
   public:
    // Perform the action associated with the specified |command_id| and
    // optional |event_flags|.
    virtual void ExecuteCommand(CefRefPtr<CefMenuModelImpl> source,
                                int command_id,
                                cef_event_flags_t event_flags) =0;

    // Notifies the delegate that the menu is about to show.
    virtual void MenuWillShow(CefRefPtr<CefMenuModelImpl> source) =0;

    // Notifies the delegate that the menu has closed.
    virtual void MenuClosed(CefRefPtr<CefMenuModelImpl> source) =0;

   protected:
    virtual ~Delegate() {}
  };

  // The delegate must outlive this class.
  explicit CefMenuModelImpl(Delegate* delegate);
  virtual ~CefMenuModelImpl();

  // CefMenuModel methods.
  virtual bool Clear() OVERRIDE;
  virtual int GetCount() OVERRIDE;
  virtual bool AddSeparator() OVERRIDE;
  virtual bool AddItem(int command_id, const CefString& label) OVERRIDE;
  virtual bool AddCheckItem(int command_id, const CefString& label) OVERRIDE;
  virtual bool AddRadioItem(int command_id, const CefString& label,
      int group_id) OVERRIDE;
  virtual CefRefPtr<CefMenuModel> AddSubMenu(int command_id,
      const CefString& label) OVERRIDE;
  virtual bool InsertSeparatorAt(int index) OVERRIDE;
  virtual bool InsertItemAt(int index, int command_id,
      const CefString& label) OVERRIDE;
  virtual bool InsertCheckItemAt(int index, int command_id,
      const CefString& label) OVERRIDE;
  virtual bool InsertRadioItemAt(int index, int command_id,
      const CefString& label, int group_id) OVERRIDE;
  virtual CefRefPtr<CefMenuModel> InsertSubMenuAt(int index, int command_id,
      const CefString& label) OVERRIDE;
  virtual bool Remove(int command_id) OVERRIDE;
  virtual bool RemoveAt(int index) OVERRIDE;
  virtual int GetIndexOf(int command_id) OVERRIDE;
  virtual int GetCommandIdAt(int index) OVERRIDE;
  virtual bool SetCommandIdAt(int index, int command_id) OVERRIDE;
  virtual CefString GetLabel(int command_id) OVERRIDE;
  virtual CefString GetLabelAt(int index) OVERRIDE;
  virtual bool SetLabel(int command_id, const CefString& label) OVERRIDE;
  virtual bool SetLabelAt(int index, const CefString& label) OVERRIDE;
  virtual MenuItemType GetType(int command_id) OVERRIDE;
  virtual MenuItemType GetTypeAt(int index) OVERRIDE;
  virtual int GetGroupId(int command_id) OVERRIDE;
  virtual int GetGroupIdAt(int index) OVERRIDE;
  virtual bool SetGroupId(int command_id, int group_id) OVERRIDE;
  virtual bool SetGroupIdAt(int index, int group_id) OVERRIDE;
  virtual CefRefPtr<CefMenuModel> GetSubMenu(int command_id) OVERRIDE;
  virtual CefRefPtr<CefMenuModel> GetSubMenuAt(int index) OVERRIDE;
  virtual bool IsVisible(int command_id) OVERRIDE;
  virtual bool IsVisibleAt(int index) OVERRIDE;
  virtual bool SetVisible(int command_id, bool visible) OVERRIDE;
  virtual bool SetVisibleAt(int index, bool visible) OVERRIDE;
  virtual bool IsEnabled(int command_id) OVERRIDE;
  virtual bool IsEnabledAt(int index) OVERRIDE;
  virtual bool SetEnabled(int command_id, bool enabled) OVERRIDE;
  virtual bool SetEnabledAt(int index, bool enabled) OVERRIDE;
  virtual bool IsChecked(int command_id) OVERRIDE;
  virtual bool IsCheckedAt(int index) OVERRIDE;
  virtual bool SetChecked(int command_id, bool checked) OVERRIDE;
  virtual bool SetCheckedAt(int index, bool checked) OVERRIDE;
  virtual bool HasAccelerator(int command_id) OVERRIDE;
  virtual bool HasAcceleratorAt(int index) OVERRIDE;
  virtual bool SetAccelerator(int command_id, int key_code, bool shift_pressed,
      bool ctrl_pressed, bool alt_pressed) OVERRIDE;
  virtual bool SetAcceleratorAt(int index, int key_code, bool shift_pressed,
      bool ctrl_pressed, bool alt_pressed) OVERRIDE;
  virtual bool RemoveAccelerator(int command_id) OVERRIDE;
  virtual bool RemoveAcceleratorAt(int index) OVERRIDE;
  virtual bool GetAccelerator(int command_id, int& key_code,
      bool& shift_pressed, bool& ctrl_pressed, bool& alt_pressed) OVERRIDE;
  virtual bool GetAcceleratorAt(int index, int& key_code, bool& shift_pressed,
      bool& ctrl_pressed, bool& alt_pressed) OVERRIDE;

  // Callbacks from the ui::MenuModel implementation.
  void ActivatedAt(int index, cef_event_flags_t event_flags);
  void MenuWillShow();
  void MenuClosed();

  // Verify that only a single reference exists to all CefMenuModelImpl objects.
  bool VerifyRefCount();

  ui::MenuModel* model() { return model_.get(); }
  Delegate* delegate() { return delegate_; }
  void set_delegate(Delegate* delegate) { delegate_ = NULL; }

 private:
  struct Item;

  typedef std::vector<Item> ItemVector;

  // Functions for inserting items into |items_|.
  void AppendItem(const Item& item);
  void InsertItemAt(const Item& item, int index);
  void ValidateItem(const Item& item);

  // Notify the delegate that the menu is closed.
  void OnMenuClosed();

  // Verify that the object is being accessed from the correct thread.
  bool VerifyContext();

  base::PlatformThreadId supported_thread_id_;
  Delegate* delegate_;
  ItemVector items_;
  scoped_ptr<ui::MenuModel> model_;

  IMPLEMENT_REFCOUNTING(CefMenuModelImpl);
  DISALLOW_COPY_AND_ASSIGN(CefMenuModelImpl);
};

#endif  // CEF_LIBCEF_BROWSER_MENU_MODEL_IMPL_H_
