#include "onig_regexp_extension.h"
#include "include/cef_base.h"
#include "include/cef_runnable.h"
#include <oniguruma.h>
#include <iostream>
#include <stdlib.h>
#include "io_utils.h"

using namespace std;

class OnigRegexpUserData: public CefBase {
public:
  OnigRegexpUserData(CefRefPtr<CefV8Value> source) {
    OnigErrorInfo error;
    string input = source->GetStringValue().ToString();
    int length = input.length();
    UChar* pattern = (UChar*) input.c_str();
    int code = onig_new(&regex, pattern, pattern + length,
        ONIG_OPTION_SINGLELINE, ONIG_ENCODING_UTF8, ONIG_SYNTAX_DEFAULT,
        &error);
    if (code != ONIG_NORMAL) {
      char errorText[ONIG_MAX_ERROR_MESSAGE_LEN];
      onig_error_code_to_str((OnigUChar*) errorText, code, &error);
      cout << errorText << " for pattern: " << input << endl;
    }
  }

  ~OnigRegexpUserData() {
    onig_free(regex);
  }

  OnigRegion* SearchRegion(string input, int index) {
    if (!regex)
      return NULL;

    OnigRegion* region = onig_region_new();
    UChar* search = (UChar*) input.c_str();
    unsigned char* start = search + index;
    unsigned char* end = search + input.length();
    int code = onig_search(regex, search, end, start, end, region,
        ONIG_OPTION_NONE);
    if (code >= 0)
      return region;
    else {
      onig_region_free(region, 1);
      return NULL;
    }
  }

  CefRefPtr<CefV8Value> Search(CefRefPtr<CefV8Value> argument,
      CefRefPtr<CefV8Value> index) {
    string input = argument->GetStringValue().ToString();
    OnigRegion* region = SearchRegion(input, index->GetIntValue());
    if (!region)
      return CefV8Value::CreateNull();

    CefRefPtr<CefV8Value> indices;
    CefRefPtr<CefV8Value> resultArray = CefV8Value::CreateArray(
        region->num_regs);
    CefRefPtr<CefV8Value> indicesArray = CefV8Value::CreateArray(
        region->num_regs);
    for (int i = 0; i < region->num_regs; i++) {
      int begin = region->beg[i];
      int end = region->end[i];
      resultArray->SetValue(i,
          CefV8Value::CreateString(input.substr(begin, end - begin)));
      indicesArray->SetValue(i, CefV8Value::CreateInt(begin));
    }
    resultArray->SetValue("index", CefV8Value::CreateInt(region->beg[0]),
        V8_PROPERTY_ATTRIBUTE_NONE);
    resultArray->SetValue("indices", indicesArray, V8_PROPERTY_ATTRIBUTE_NONE);
    onig_region_free(region, 1);
    return resultArray;
  }

  CefRefPtr<CefV8Value> Test(CefRefPtr<CefV8Value> argument,
      CefRefPtr<CefV8Value> index) {
    OnigRegion* region = SearchRegion(argument->GetStringValue().ToString(),
        index->GetIntValue());
    CefRefPtr<CefV8Value> text = CefV8Value::CreateBool(region != NULL);
    if (region)
      onig_region_free(region, 1);
    return text;
  }

  CefRefPtr<CefV8Value> GetCaptureIndices(CefRefPtr<CefV8Value> argument,
      CefRefPtr<CefV8Value> index) {
    OnigRegion* region = SearchRegion(argument->GetStringValue().ToString(),
        index->GetIntValue());
    CefRefPtr<CefV8Value> indices;
    if (region) {
      indices = BuildCaptureIndices(region);
      onig_region_free(region, 1);
    } else
      indices = CefV8Value::CreateNull();
    return indices;
  }

  CefRefPtr<CefV8Value> BuildCaptureIndices(OnigRegion *region) {
    CefRefPtr<CefV8Value> array = CefV8Value::CreateArray(region->num_regs * 3);
    int i = 0;
    for (int index = 0; index < region->num_regs; index++) {
      int begin = region->beg[index];
      int end = region->end[index];
      if (end - begin <= 0)
        continue;
      array->SetValue(i++, CefV8Value::CreateInt(index));
      array->SetValue(i++, CefV8Value::CreateInt(begin));
      array->SetValue(i++, CefV8Value::CreateInt(end));
    }

    return array;
  }

  CefRefPtr<CefV8Value> CaptureCount() {
    if (regex)
      return CefV8Value::CreateInt(onig_number_of_captures(regex));
    else
      return CefV8Value::CreateInt(0);
  }

  regex_t* regex;

IMPLEMENT_REFCOUNTING(OnigRegexpUserData)
  ;
}
;

OnigRegexpExtension::OnigRegexpExtension() :
    CefV8Handler() {
  string realFilePath = io_utils_real_app_path(
      "/native/v8_extensions/onig_reg_exp.js");
  if (!realFilePath.empty()) {
    string extensionCode;
    if (io_utils_read(realFilePath, &extensionCode) > 0)
      CefRegisterExtension("v8/onig-reg-exp", extensionCode, this);
  }
}

bool OnigRegexpExtension::Execute(const CefString& name,
    CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments,
    CefRefPtr<CefV8Value>& retval, CefString& exception) {
  if (name == "captureIndices") {
    CefRefPtr<CefV8Value> string = arguments[0];
    CefRefPtr<CefV8Value> index = arguments[1];
    CefRefPtr<CefV8Value> regexes = arguments[2];

    int bestIndex = -1;
    CefRefPtr<CefV8Value> captureIndicesForBestIndex;
    CefRefPtr<CefV8Value> captureIndices;

    retval = CefV8Value::CreateObject(NULL);
    for (int i = 0; i < regexes->GetArrayLength(); i++) {
      OnigRegexpUserData *userData =
          (OnigRegexpUserData *) regexes->GetValue(i)->GetUserData().get();
      captureIndices = userData->GetCaptureIndices(string, index);
      if (captureIndices->IsNull())
        continue;

      if (bestIndex == -1
          || captureIndices->GetValue(1)->GetIntValue()
              < captureIndicesForBestIndex->GetValue(1)->GetIntValue()) {
        bestIndex = i;
        captureIndicesForBestIndex = captureIndices;
        if (captureIndices->GetValue(1)->GetIntValue() == 0)
          break; // If the match starts at 0, just use it!
      }
    }

    if (bestIndex != -1) {
      retval->SetValue("index", CefV8Value::CreateInt(bestIndex),
          V8_PROPERTY_ATTRIBUTE_NONE);
      retval->SetValue("captureIndices", captureIndicesForBestIndex,
          V8_PROPERTY_ATTRIBUTE_NONE);
    }

    return true;

  }

  if (name == "getCaptureIndices") {
    CefRefPtr<CefV8Value> string = arguments[0];
    CefRefPtr<CefV8Value> index =
        arguments.size() > 1 ? arguments[1] : CefV8Value::CreateInt(0);
    OnigRegexpUserData *userData =
        (OnigRegexpUserData *) object->GetUserData().get();
    retval = userData->GetCaptureIndices(string, index);
    return true;
  }

  if (name == "search") {
    CefRefPtr<CefV8Value> string = arguments[0];
    CefRefPtr<CefV8Value> index =
        arguments.size() > 1 ? arguments[1] : CefV8Value::CreateInt(0);
    OnigRegexpUserData *userData =
        (OnigRegexpUserData *) object->GetUserData().get();
    retval = userData->Search(string, index);
    return true;
  }

  if (name == "test") {
    CefRefPtr<CefV8Value> string = arguments[0];
    CefRefPtr<CefV8Value> index =
        arguments.size() > 1 ? arguments[1] : CefV8Value::CreateInt(0);
    OnigRegexpUserData *userData =
        (OnigRegexpUserData *) object->GetUserData().get();
    retval = userData->Test(string, index);
    return true;
  }

  if (name == "buildOnigRegExp") {
    CefRefPtr<CefBase> userData = new OnigRegexpUserData(arguments[0]);
    retval = CefV8Value::CreateObject(NULL);
    retval->SetUserData(userData);
    return true;
  }

  if (name == "getCaptureCount") {
    OnigRegexpUserData *userData =
        (OnigRegexpUserData *) object->GetUserData().get();
    retval = userData->CaptureCount();
    return true;
  }

  return false;
}
