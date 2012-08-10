// Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "libcef/browser/xml_reader_impl.h"
#include "include/cef_stream.h"
#include "base/logging.h"

// Static functions

// static
CefRefPtr<CefXmlReader> CefXmlReader::Create(CefRefPtr<CefStreamReader> stream,
                                             EncodingType encodingType,
                                             const CefString& URI) {
  CefRefPtr<CefXmlReaderImpl> impl(new CefXmlReaderImpl());
  if (!impl->Initialize(stream, encodingType, URI))
    return NULL;
  return impl.get();
}


// CefXmlReaderImpl

namespace {

/**
 * xmlInputReadCallback:
 * @context:  an Input context
 * @buffer:  the buffer to store data read
 * @len:  the length of the buffer in bytes
 *
 * Callback used in the I/O Input API to read the resource
 *
 * Returns the number of bytes read or -1 in case of error
 */
int XMLCALL xml_read_callback(void * context, char * buffer, int len) {
  CefRefPtr<CefStreamReader> reader(static_cast<CefStreamReader*>(context));
  return reader->Read(buffer, 1, len);
}

/**
 * xmlTextReaderErrorFunc:
 * @arg: the user argument
 * @msg: the message
 * @severity: the severity of the error
 * @locator: a locator indicating where the error occured
 *
 * Signature of an error callback from a reader parser
 */
void XMLCALL xml_error_callback(void *arg, const char *msg,
                                xmlParserSeverities severity,
                                xmlTextReaderLocatorPtr locator) {
  if (!msg)
    return;

  std::string error_str(msg);
  if (!error_str.empty() && error_str[error_str.length()-1] == '\n')
    error_str.resize(error_str.length()-1);

  std::stringstream ss;
  ss << error_str << ", line " << xmlTextReaderLocatorLineNumber(locator);

  LOG(INFO) << ss.str();

  CefRefPtr<CefXmlReaderImpl> impl(static_cast<CefXmlReaderImpl*>(arg));
  impl->AppendError(ss.str());
}

/**
 * xmlStructuredErrorFunc:
 * @userData:  user provided data for the error callback
 * @error:  the error being raised.
 *
 * Signature of the function to use when there is an error and
 * the module handles the new error reporting mechanism.
 */
void XMLCALL xml_structured_error_callback(void *userData, xmlErrorPtr error) {
  if (!error->message)
    return;

  std::string error_str(error->message);
  if (!error_str.empty() && error_str[error_str.length()-1] == '\n')
    error_str.resize(error_str.length()-1);

  std::stringstream ss;
  ss << error_str << ", line " << error->line;

  LOG(INFO) << ss.str();

  CefRefPtr<CefXmlReaderImpl> impl(static_cast<CefXmlReaderImpl*>(userData));
  impl->AppendError(ss.str());
}

CefString xmlCharToString(const xmlChar* xmlStr, bool free) {
  if (!xmlStr)
    return CefString();

  const char* str = reinterpret_cast<const char*>(xmlStr);
  CefString wstr = std::string(str);

  if (free)
    xmlFree(const_cast<xmlChar*>(xmlStr));

  return wstr;
}

}  // namespace

CefXmlReaderImpl::CefXmlReaderImpl()
  : supported_thread_id_(base::PlatformThread::CurrentId()), reader_(NULL) {
}

CefXmlReaderImpl::~CefXmlReaderImpl() {
  if (reader_ != NULL) {
    if (!VerifyContext()) {
      // Close() is supposed to be called directly. We'll try to free the reader
      // now on the wrong thread but there's no guarantee this call won't crash.
      xmlFreeTextReader(reader_);
    } else {
      Close();
    }
  }
}

bool CefXmlReaderImpl::Initialize(CefRefPtr<CefStreamReader> stream,
                                  EncodingType encodingType,
                                  const CefString& URI) {
  xmlCharEncoding enc = XML_CHAR_ENCODING_NONE;
  switch (encodingType) {
    case XML_ENCODING_UTF8:
      enc = XML_CHAR_ENCODING_UTF8;
      break;
    case XML_ENCODING_UTF16LE:
      enc = XML_CHAR_ENCODING_UTF16LE;
      break;
    case XML_ENCODING_UTF16BE:
      enc = XML_CHAR_ENCODING_UTF16BE;
      break;
    case XML_ENCODING_ASCII:
      enc = XML_CHAR_ENCODING_ASCII;
      break;
    default:
      break;
  }

  // Create the input buffer.
  xmlParserInputBufferPtr input_buffer = xmlAllocParserInputBuffer(enc);
  if (!input_buffer)
    return false;

  input_buffer->context = stream.get();
  input_buffer->readcallback = xml_read_callback;

  // Create the text reader.
  std::string uriStr = URI;
  reader_ = xmlNewTextReader(input_buffer, uriStr.c_str());
  if (!reader_) {
    // Free the input buffer.
    xmlFreeParserInputBuffer(input_buffer);
    return false;
  }

  // Keep a reference to the stream.
  stream_ = stream;

  // Register the error callbacks.
  xmlTextReaderSetErrorHandler(reader_, xml_error_callback, this);
  xmlTextReaderSetStructuredErrorHandler(reader_,
      xml_structured_error_callback, this);

  return true;
}

bool CefXmlReaderImpl::MoveToNextNode() {
  if (!VerifyContext())
    return false;

  return xmlTextReaderRead(reader_) == 1 ? true : false;
}

bool CefXmlReaderImpl::Close() {
  if (!VerifyContext())
    return false;

  // The input buffer will be freed automatically.
  xmlFreeTextReader(reader_);
  reader_ = NULL;
  return true;
}

bool CefXmlReaderImpl::HasError() {
  if (!VerifyContext())
    return false;

  return !error_buf_.str().empty();
}

CefString CefXmlReaderImpl::GetError() {
  if (!VerifyContext())
    return CefString();

  return error_buf_.str();
}

CefXmlReader::NodeType CefXmlReaderImpl::GetType() {
  if (!VerifyContext())
    return XML_NODE_UNSUPPORTED;

  switch (xmlTextReaderNodeType(reader_)) {
    case XML_READER_TYPE_ELEMENT:
      return XML_NODE_ELEMENT_START;
    case XML_READER_TYPE_END_ELEMENT:
      return XML_NODE_ELEMENT_END;
    case XML_READER_TYPE_ATTRIBUTE:
      return XML_NODE_ATTRIBUTE;
    case XML_READER_TYPE_TEXT:
      return XML_NODE_TEXT;
    case XML_READER_TYPE_SIGNIFICANT_WHITESPACE:
    case XML_READER_TYPE_WHITESPACE:
      return XML_NODE_WHITESPACE;
    case XML_READER_TYPE_CDATA:
      return XML_NODE_CDATA;
    case XML_READER_TYPE_ENTITY_REFERENCE:
      return XML_NODE_ENTITY_REFERENCE;
    case XML_READER_TYPE_PROCESSING_INSTRUCTION:
      return XML_NODE_PROCESSING_INSTRUCTION;
    case XML_READER_TYPE_COMMENT:
      return XML_NODE_COMMENT;
    case XML_READER_TYPE_DOCUMENT_TYPE:
      return XML_NODE_DOCUMENT_TYPE;
    default:
      break;
  }

  return XML_NODE_UNSUPPORTED;
}

int CefXmlReaderImpl::GetDepth() {
  if (!VerifyContext())
    return -1;

  return xmlTextReaderDepth(reader_);
}

CefString CefXmlReaderImpl::GetLocalName() {
  if (!VerifyContext())
    return CefString();

  return xmlCharToString(xmlTextReaderConstLocalName(reader_), false);
}

CefString CefXmlReaderImpl::GetPrefix() {
  if (!VerifyContext())
    return CefString();

  return xmlCharToString(xmlTextReaderConstPrefix(reader_), false);
}

CefString CefXmlReaderImpl::GetQualifiedName() {
  if (!VerifyContext())
    return CefString();

  return xmlCharToString(xmlTextReaderConstName(reader_), false);
}

CefString CefXmlReaderImpl::GetNamespaceURI() {
  if (!VerifyContext())
    return CefString();

  return xmlCharToString(xmlTextReaderConstNamespaceUri(reader_), false);
}

CefString CefXmlReaderImpl::GetBaseURI() {
  if (!VerifyContext())
    return CefString();

  return xmlCharToString(xmlTextReaderConstBaseUri(reader_), false);
}

CefString CefXmlReaderImpl::GetXmlLang() {
  if (!VerifyContext())
    return CefString();

  return xmlCharToString(xmlTextReaderConstXmlLang(reader_), false);
}

bool CefXmlReaderImpl::IsEmptyElement() {
  if (!VerifyContext())
    return false;

  return xmlTextReaderIsEmptyElement(reader_) == 1 ? true : false;
}

bool CefXmlReaderImpl::HasValue() {
  if (!VerifyContext())
    return false;

  if (xmlTextReaderNodeType(reader_) == XML_READER_TYPE_ENTITY_REFERENCE) {
    // Provide special handling to return entity reference values.
    return true;
  } else {
    return xmlTextReaderHasValue(reader_) == 1 ? true : false;
  }
}

CefString CefXmlReaderImpl::GetValue() {
  if (!VerifyContext())
    return CefString();

  if (xmlTextReaderNodeType(reader_) == XML_READER_TYPE_ENTITY_REFERENCE) {
    // Provide special handling to return entity reference values.
    xmlNodePtr node = xmlTextReaderCurrentNode(reader_);
    if (node->content != NULL)
      return xmlCharToString(node->content, false);
    return CefString();
  } else {
    return xmlCharToString(xmlTextReaderConstValue(reader_), false);
  }
}

bool CefXmlReaderImpl::HasAttributes() {
  if (!VerifyContext())
    return false;

  return xmlTextReaderHasAttributes(reader_) == 1 ? true : false;
}

size_t CefXmlReaderImpl::GetAttributeCount() {
  if (!VerifyContext())
    return 0;

  return xmlTextReaderAttributeCount(reader_);
}

CefString CefXmlReaderImpl::GetAttribute(int index) {
  if (!VerifyContext())
    return CefString();

  return xmlCharToString(xmlTextReaderGetAttributeNo(reader_, index), true);
}

CefString CefXmlReaderImpl::GetAttribute(const CefString& qualifiedName) {
  if (!VerifyContext())
    return CefString();

  std::string qualifiedNameStr = qualifiedName;
  return xmlCharToString(xmlTextReaderGetAttribute(reader_,
      BAD_CAST qualifiedNameStr.c_str()), true);
}

CefString CefXmlReaderImpl::GetAttribute(const CefString& localName,
                                         const CefString& namespaceURI) {
  if (!VerifyContext())
    return CefString();

  std::string localNameStr = localName;
  std::string namespaceURIStr = namespaceURI;
  return xmlCharToString(xmlTextReaderGetAttributeNs(reader_,
      BAD_CAST localNameStr.c_str(), BAD_CAST namespaceURIStr.c_str()), true);
}

CefString CefXmlReaderImpl::GetInnerXml() {
  if (!VerifyContext())
    return CefString();

  return xmlCharToString(xmlTextReaderReadInnerXml(reader_), true);
}

CefString CefXmlReaderImpl::GetOuterXml() {
  if (!VerifyContext())
    return CefString();

  return xmlCharToString(xmlTextReaderReadOuterXml(reader_), true);
}

int CefXmlReaderImpl::GetLineNumber() {
  if (!VerifyContext())
    return -1;

  return xmlTextReaderGetParserLineNumber(reader_);
}

bool CefXmlReaderImpl::MoveToAttribute(int index) {
  if (!VerifyContext())
    return false;

  return xmlTextReaderMoveToAttributeNo(reader_, index) == 1 ? true : false;
}

bool CefXmlReaderImpl::MoveToAttribute(const CefString& qualifiedName) {
  if (!VerifyContext())
    return false;

  std::string qualifiedNameStr = qualifiedName;
  return xmlTextReaderMoveToAttribute(reader_,
      BAD_CAST qualifiedNameStr.c_str()) == 1 ? true : false;
}

bool CefXmlReaderImpl::MoveToAttribute(const CefString& localName,
                                       const CefString& namespaceURI) {
  if (!VerifyContext())
    return false;

  std::string localNameStr = localName;
  std::string namespaceURIStr = namespaceURI;
  return xmlTextReaderMoveToAttributeNs(reader_,
      BAD_CAST localNameStr.c_str(), BAD_CAST namespaceURIStr.c_str()) == 1 ?
      true : false;
}

bool CefXmlReaderImpl::MoveToFirstAttribute() {
  if (!VerifyContext())
    return false;

  return xmlTextReaderMoveToFirstAttribute(reader_) == 1 ? true : false;
}

bool CefXmlReaderImpl::MoveToNextAttribute() {
  if (!VerifyContext())
    return false;

  return xmlTextReaderMoveToNextAttribute(reader_) == 1 ? true : false;
}

bool CefXmlReaderImpl::MoveToCarryingElement() {
  if (!VerifyContext())
    return false;

  return xmlTextReaderMoveToElement(reader_) == 1 ? true : false;
}

void CefXmlReaderImpl::AppendError(const CefString& error_str) {
  if (!error_buf_.str().empty())
    error_buf_ << L"\n";
  error_buf_ << error_str;
}

bool CefXmlReaderImpl::VerifyContext() {
  if (base::PlatformThread::CurrentId() != supported_thread_id_) {
    // This object should only be accessed from the thread that created it.
    NOTREACHED();
    return false;
  }

  return (reader_ != NULL);
}
