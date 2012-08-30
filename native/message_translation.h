#ifndef ATOM_CEF_CLIENT_H_
#define ATOM_CEF_CLIENT_H_
#pragma once

#include "include/cef_v8.h"

// IPC data translation functions: translate a V8 array to a List, and vice versa
void TranslateList(CefRefPtr<CefV8Value> source, CefRefPtr<CefListValue> target);
void TranslateList(CefRefPtr<CefListValue> source, CefRefPtr<CefV8Value> target);

#endif