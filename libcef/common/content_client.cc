// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/common/content_client.h"
#include "include/cef_stream.h"
#include "include/cef_version.h"
#include "libcef/browser/devtools_scheme_handler.h"
#include "libcef/common/cef_switches.h"
#include "libcef/common/scheme_registrar_impl.h"
#include "libcef/renderer/content_renderer_client.h"

#include "base/command_line.h"
#include "base/logging.h"
#include "base/string_piece.h"
#include "base/stringprintf.h"
#include "content/public/common/content_switches.h"
#include "ui/base/resource/resource_bundle.h"
#include "webkit/glue/user_agent.h"

CefContentClient::CefContentClient(CefRefPtr<CefApp> application)
    : application_(application),
      pack_loading_disabled_(false),
      allow_pack_file_load_(false) {
}

CefContentClient::~CefContentClient() {
}

// static
CefContentClient* CefContentClient::Get() {
  return static_cast<CefContentClient*>(content::GetContentClient());
}

void CefContentClient::AddAdditionalSchemes(
    std::vector<std::string>* standard_schemes,
    std::vector<std::string>* savable_schemes) {
  if (application_.get()) {
    CefRefPtr<CefSchemeRegistrarImpl> schemeRegistrar(
        new CefSchemeRegistrarImpl());
    application_->OnRegisterCustomSchemes(schemeRegistrar.get());
    schemeRegistrar->GetStandardSchemes(standard_schemes);

    // No references to the registar should be kept.
    schemeRegistrar->Detach();
    DCHECK(schemeRegistrar->VerifyRefCount());
  }

  standard_schemes->push_back(kChromeDevToolsScheme);
  if (CefContentRendererClient::Get()) {
    // Register the DevTools scheme with WebKit.
    CefContentRendererClient::Get()->AddCustomScheme(kChromeDevToolsScheme,
                                                     true, false);
  }
}

std::string CefContentClient::GetUserAgent() const {
  std::string product_version;

  static CommandLine& command_line = *CommandLine::ForCurrentProcess();
  if (command_line.HasSwitch(switches::kProductVersion)) {
    product_version =
        command_line.GetSwitchValueASCII(switches::kProductVersion);
  } else {
    product_version = base::StringPrintf("Chrome/%d.%d.%d.%d",
        CHROME_VERSION_MAJOR, CHROME_VERSION_MINOR, CHROME_VERSION_BUILD,
        CHROME_VERSION_PATCH);
  }

  return webkit_glue::BuildUserAgentFromProduct(product_version);
}

string16 CefContentClient::GetLocalizedString(int message_id) const {
  string16 value =
      ResourceBundle::GetSharedInstance().GetLocalizedString(message_id);
  if (value.empty())
    LOG(ERROR) << "No localized string available for id " << message_id;

  return value;
}

base::StringPiece CefContentClient::GetDataResource(
    int resource_id,
    ui::ScaleFactor scale_factor) const {
  base::StringPiece value =
      ResourceBundle::GetSharedInstance().GetRawDataResource(resource_id,
                                                             scale_factor);
  if (value.empty())
    LOG(ERROR) << "No data resource available for id " << resource_id;

  return value;
}

FilePath CefContentClient::GetPathForResourcePack(
    const FilePath& pack_path,
    ui::ScaleFactor scale_factor) {
  // Only allow the cef pack file to load.
  if (!pack_loading_disabled_ && allow_pack_file_load_)
    return pack_path;
  return FilePath();
}

FilePath CefContentClient::GetPathForLocalePack(const FilePath& pack_path,
                                                const std::string& locale) {
  if (!pack_loading_disabled_)
    return pack_path;
  return FilePath();
}

gfx::Image CefContentClient::GetImageNamed(int resource_id) {
  return gfx::Image();
}

gfx::Image CefContentClient::GetNativeImageNamed(
    int resource_id,
    ui::ResourceBundle::ImageRTL rtl) {
  return gfx::Image();
}

base::RefCountedStaticMemory* CefContentClient::LoadDataResourceBytes(
    int resource_id,
    ui::ScaleFactor scale_factor) {
  return NULL;
}

bool CefContentClient::GetRawDataResource(int resource_id,
                                          ui::ScaleFactor scale_factor,
                                          base::StringPiece* value) {
  if (application_.get()) {
    CefRefPtr<CefResourceBundleHandler> handler =
        application_->GetResourceBundleHandler();
    if (handler.get()) {
      void* data = NULL;
      size_t data_size = 0;
      if (handler->GetDataResource(resource_id, data, data_size))
        *value = base::StringPiece(static_cast<char*>(data), data_size);
    }
  }

  return (pack_loading_disabled_ || !value->empty());
}

bool CefContentClient::GetLocalizedString(int message_id, string16* value) {
  if (application_.get()) {
    CefRefPtr<CefResourceBundleHandler> handler =
        application_->GetResourceBundleHandler();
    if (handler.get()) {
      CefString cef_str;
      if (handler->GetLocalizedString(message_id, cef_str))
        *value = cef_str;
    }
  }

  return (pack_loading_disabled_ || !value->empty());
}

scoped_ptr<gfx::Font> CefContentClient::GetFont(
    ui::ResourceBundle::FontStyle style) {
  return scoped_ptr<gfx::Font>();
}
