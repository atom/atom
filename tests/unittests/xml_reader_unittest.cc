// Copyright (c) 2010 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/cef_stream.h"
#include "include/cef_xml_reader.h"
#include "include/wrapper/cef_xml_object.h"
#include "testing/gtest/include/gtest/gtest.h"

namespace {

char g_test_xml[] =
    "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n"
    "<?my_instruction my_value?>\n"
    "<!DOCTYPE my_document SYSTEM \"example.dtd\" [\n"
    "    <!ENTITY EA \"EA Value\">\n"
    "    <!ENTITY EB \"EB Value\">\n"
    "]>\n"
    "<ns:obj xmlns:ns=\"http://www.example.org/ns\">\n"
    "  <ns:objA>value A</ns:objA>\n"
    "  <!-- my comment -->\n"
    "  <ns:objB>\n"
    "    <ns:objB_1>value B1</ns:objB_1>\n"
    "    <ns:objB_2><![CDATA[some <br/> data]]></ns:objB_2>\n"
    "    <ns:objB_3>&EB;</ns:objB_3>\n"
    "    <ns:objB_4><b>this is</b> mixed content &EA;</ns:objB_4>\n"
    "  </ns:objB>\n"
    "  <ns:objC ns:attr1=\"value C1\" ns:attr2=\"value C2\"/><ns:objD>"
    "</ns:objD>\n"
    "</ns:obj>\n";

}  // namespace

// Test XML reading
TEST(XmlReaderTest, Read) {
  // Create the stream reader.
  CefRefPtr<CefStreamReader> stream(
      CefStreamReader::CreateForData(g_test_xml, sizeof(g_test_xml) - 1));
  ASSERT_TRUE(stream.get() != NULL);

  // Create the XML reader.
  CefRefPtr<CefXmlReader> reader(
      CefXmlReader::Create(stream, XML_ENCODING_NONE,
      "http://www.example.org/example.xml"));
  ASSERT_TRUE(reader.get() != NULL);

  // Move to the processing instruction node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 0);
  ASSERT_EQ(reader->GetType(), XML_NODE_PROCESSING_INSTRUCTION);
  ASSERT_EQ(reader->GetLocalName(), "my_instruction");
  ASSERT_EQ(reader->GetQualifiedName(), "my_instruction");
  ASSERT_TRUE(reader->HasValue());
  ASSERT_EQ(reader->GetValue(), "my_value");

  // Move to the DOCTYPE node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 0);
  ASSERT_EQ(reader->GetType(), XML_NODE_DOCUMENT_TYPE);
  ASSERT_EQ(reader->GetLocalName(), "my_document");
  ASSERT_EQ(reader->GetQualifiedName(), "my_document");
  ASSERT_FALSE(reader->HasValue());

  // Move to ns:obj element start node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 0);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_START);
  ASSERT_EQ(reader->GetLocalName(), "obj");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:obj");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_TRUE(reader->HasAttributes());
  ASSERT_EQ(reader->GetAttributeCount(), (size_t)1);
  ASSERT_EQ(reader->GetAttribute(0), "http://www.example.org/ns");
  ASSERT_EQ(reader->GetAttribute("xmlns:ns"), "http://www.example.org/ns");
  ASSERT_EQ(reader->GetAttribute("ns", "http://www.w3.org/2000/xmlns/"),
      "http://www.example.org/ns");

  // Move to the whitespace node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetType(), XML_NODE_WHITESPACE);

  // Move to the ns:objA element start node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 1);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_START);
  ASSERT_EQ(reader->GetLocalName(), "objA");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objA");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());

  // Move to the ns:objA value node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 2);
  ASSERT_EQ(reader->GetType(), XML_NODE_TEXT);
  ASSERT_EQ(reader->GetLocalName(), "#text");
  ASSERT_EQ(reader->GetQualifiedName(), "#text");
  ASSERT_TRUE(reader->HasValue());
  ASSERT_EQ(reader->GetValue(), "value A");

  // Move to the ns:objA element ending node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 1);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_END);
  ASSERT_EQ(reader->GetLocalName(), "objA");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objA");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());

  // Move to the whitespace node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 1);
  ASSERT_EQ(reader->GetType(), XML_NODE_WHITESPACE);

  // Move to the comment node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 1);
  ASSERT_EQ(reader->GetType(), XML_NODE_COMMENT);
  ASSERT_EQ(reader->GetLocalName(), "#comment");
  ASSERT_EQ(reader->GetQualifiedName(), "#comment");
  ASSERT_TRUE(reader->HasValue());
  ASSERT_EQ(reader->GetValue(), " my comment ");

  // Move to the whitespace node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetType(), XML_NODE_WHITESPACE);

  // Move to the ns:objB element start node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 1);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_START);
  ASSERT_EQ(reader->GetLocalName(), "objB");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objB");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());

  // Move to the whitespace node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetType(), XML_NODE_WHITESPACE);

  // Move to the ns:objB_1 element start node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 2);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_START);
  ASSERT_EQ(reader->GetLocalName(), "objB_1");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objB_1");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());

  // Move to the ns:objB_1 value node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 3);
  ASSERT_EQ(reader->GetType(), XML_NODE_TEXT);
  ASSERT_TRUE(reader->HasValue());
  ASSERT_EQ(reader->GetValue(), "value B1");

  // Move to the ns:objB_1 element ending node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 2);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_END);
  ASSERT_EQ(reader->GetLocalName(), "objB_1");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objB_1");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());

  // Move to the whitespace node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetType(), XML_NODE_WHITESPACE);

  // Move to the ns:objB_2 element start node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 2);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_START);
  ASSERT_EQ(reader->GetLocalName(), "objB_2");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objB_2");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());

  // Move to the ns:objB_2 value node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 3);
  ASSERT_EQ(reader->GetType(), XML_NODE_CDATA);
  ASSERT_TRUE(reader->HasValue());
  ASSERT_EQ(reader->GetValue(), "some <br/> data");

  // Move to the ns:objB_2 element ending node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 2);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_END);
  ASSERT_EQ(reader->GetLocalName(), "objB_2");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objB_2");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());

  // Move to the whitespace node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetType(), XML_NODE_WHITESPACE);

  // Move to the ns:objB_3 element start node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 2);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_START);
  ASSERT_EQ(reader->GetLocalName(), "objB_3");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objB_3");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());

  // Move to the EB entity reference node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 3);
  ASSERT_EQ(reader->GetType(), XML_NODE_ENTITY_REFERENCE);
  ASSERT_EQ(reader->GetLocalName(), "EB");
  ASSERT_EQ(reader->GetQualifiedName(), "EB");
  ASSERT_TRUE(reader->HasValue());
  ASSERT_EQ(reader->GetValue(), "EB Value");

  // Move to the ns:objB_3 element ending node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 2);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_END);
  ASSERT_EQ(reader->GetLocalName(), "objB_3");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objB_3");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());

  // Move to the whitespace node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetType(), XML_NODE_WHITESPACE);

  // Move to the ns:objB_4 element start node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 2);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_START);
  ASSERT_EQ(reader->GetLocalName(), "objB_4");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objB_4");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());
  ASSERT_EQ(reader->GetInnerXml(), "<b>this is</b> mixed content &EA;");
  ASSERT_EQ(reader->GetOuterXml(),
      "<ns:objB_4 xmlns:ns=\"http://www.example.org/ns\">"
      "<b>this is</b> mixed content &EA;</ns:objB_4>");

  // Move to the <b> element node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 3);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_START);
  ASSERT_EQ(reader->GetLocalName(), "b");
  ASSERT_EQ(reader->GetQualifiedName(), "b");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());

  // Move to the text node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 4);
  ASSERT_EQ(reader->GetType(), XML_NODE_TEXT);
  ASSERT_EQ(reader->GetLocalName(), "#text");
  ASSERT_EQ(reader->GetQualifiedName(), "#text");
  ASSERT_TRUE(reader->HasValue());
  ASSERT_EQ(reader->GetValue(), "this is");

  // Move to the </b> element node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 3);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_END);
  ASSERT_EQ(reader->GetLocalName(), "b");
  ASSERT_EQ(reader->GetQualifiedName(), "b");

  // Move to the text node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 3);
  ASSERT_EQ(reader->GetType(), XML_NODE_TEXT);
  ASSERT_EQ(reader->GetLocalName(), "#text");
  ASSERT_EQ(reader->GetQualifiedName(), "#text");
  ASSERT_TRUE(reader->HasValue());
  ASSERT_EQ(reader->GetValue(), " mixed content ");

  // Move to the EA entity reference node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 3);
  ASSERT_EQ(reader->GetType(), XML_NODE_ENTITY_REFERENCE);
  ASSERT_EQ(reader->GetLocalName(), "EA");
  ASSERT_EQ(reader->GetQualifiedName(), "EA");
  ASSERT_TRUE(reader->HasValue());
  ASSERT_EQ(reader->GetValue(), "EA Value");

  // Move to the ns:objB_4 element ending node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 2);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_END);
  ASSERT_EQ(reader->GetLocalName(), "objB_4");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objB_4");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());

  // Move to the whitespace node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetType(), XML_NODE_WHITESPACE);

  // Move to the ns:objB element ending node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 1);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_END);
  ASSERT_EQ(reader->GetLocalName(), "objB");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objB");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());

  // Move to the whitespace node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetType(), XML_NODE_WHITESPACE);

  // Move to the ns:objC element start node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 1);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_START);
  ASSERT_EQ(reader->GetLocalName(), "objC");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objC");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_TRUE(reader->IsEmptyElement());
  ASSERT_TRUE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());
  ASSERT_EQ(reader->GetAttributeCount(), (size_t)2);
  ASSERT_EQ(reader->GetAttribute(0), "value C1");
  ASSERT_EQ(reader->GetAttribute("ns:attr1"), "value C1");
  ASSERT_EQ(reader->GetAttribute("attr1", "http://www.example.org/ns"),
      "value C1");
  ASSERT_EQ(reader->GetAttribute(1), "value C2");
  ASSERT_EQ(reader->GetAttribute("ns:attr2"), "value C2");
  ASSERT_EQ(reader->GetAttribute("attr2", "http://www.example.org/ns"),
      "value C2");

  // Move to the ns:attr1 attribute.
  ASSERT_TRUE(reader->MoveToFirstAttribute());
  ASSERT_EQ(reader->GetDepth(), 2);
  ASSERT_EQ(reader->GetType(), XML_NODE_ATTRIBUTE);
  ASSERT_EQ(reader->GetLocalName(), "attr1");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:attr1");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_TRUE(reader->HasValue());
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_EQ(reader->GetValue(), "value C1");

  // Move to the ns:attr2 attribute.
  ASSERT_TRUE(reader->MoveToNextAttribute());
  ASSERT_EQ(reader->GetDepth(), 2);
  ASSERT_EQ(reader->GetType(), XML_NODE_ATTRIBUTE);
  ASSERT_EQ(reader->GetLocalName(), "attr2");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:attr2");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_TRUE(reader->HasValue());
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_EQ(reader->GetValue(), "value C2");

  // No more attributes.
  ASSERT_FALSE(reader->MoveToNextAttribute());

  // Return to the ns:objC element start node.
  ASSERT_TRUE(reader->MoveToCarryingElement());
  ASSERT_EQ(reader->GetDepth(), 1);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_START);
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objC");

  // Move to the ns:attr1 attribute.
  ASSERT_TRUE(reader->MoveToAttribute(0));
  ASSERT_EQ(reader->GetDepth(), 2);
  ASSERT_EQ(reader->GetType(), XML_NODE_ATTRIBUTE);
  ASSERT_EQ(reader->GetLocalName(), "attr1");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:attr1");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_TRUE(reader->HasValue());
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_EQ(reader->GetValue(), "value C1");

  // Return to the ns:objC element start node.
  ASSERT_TRUE(reader->MoveToCarryingElement());
  ASSERT_EQ(reader->GetDepth(), 1);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_START);
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objC");

  // Move to the ns:attr2 attribute.
  ASSERT_TRUE(reader->MoveToAttribute("ns:attr2"));
  ASSERT_EQ(reader->GetDepth(), 2);
  ASSERT_EQ(reader->GetType(), XML_NODE_ATTRIBUTE);
  ASSERT_EQ(reader->GetLocalName(), "attr2");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:attr2");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_TRUE(reader->HasValue());
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_EQ(reader->GetValue(), "value C2");

  // Move to the ns:attr1 attribute without returning to the ns:objC element.
  ASSERT_TRUE(reader->MoveToAttribute("attr1", "http://www.example.org/ns"));
  ASSERT_EQ(reader->GetDepth(), 2);
  ASSERT_EQ(reader->GetType(), XML_NODE_ATTRIBUTE);
  ASSERT_EQ(reader->GetLocalName(), "attr1");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:attr1");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_TRUE(reader->HasValue());
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_EQ(reader->GetValue(), "value C1");

  // Move to the ns:objD element start node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 1);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_START);
  ASSERT_EQ(reader->GetLocalName(), "objD");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objD");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());

  // Move to the ns:objD element end node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 1);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_END);
  ASSERT_EQ(reader->GetLocalName(), "objD");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:objD");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_FALSE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());

  // Move to the whitespace node without returning to the ns:objC element.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetType(), XML_NODE_WHITESPACE);

  // Move to ns:obj element ending node.
  ASSERT_TRUE(reader->MoveToNextNode());
  ASSERT_EQ(reader->GetDepth(), 0);
  ASSERT_EQ(reader->GetType(), XML_NODE_ELEMENT_END);
  ASSERT_EQ(reader->GetLocalName(), "obj");
  ASSERT_EQ(reader->GetPrefix(), "ns");
  ASSERT_EQ(reader->GetQualifiedName(), "ns:obj");
  ASSERT_EQ(reader->GetNamespaceURI(), "http://www.example.org/ns");
  ASSERT_FALSE(reader->IsEmptyElement());
  ASSERT_TRUE(reader->HasAttributes());
  ASSERT_FALSE(reader->HasValue());
  // Strangely, the end node will report if the starting node has attributes
  // but will not provide access to them.
  ASSERT_TRUE(reader->HasAttributes());
  ASSERT_EQ(reader->GetAttributeCount(), (size_t)0);

  // And we're done.
  ASSERT_FALSE(reader->MoveToNextNode());

  ASSERT_TRUE(reader->Close());
}

// Test XML read error handling.
TEST(XmlReaderTest, ReadError) {
  char test_str[] =
    "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n"
    "<!ATTRIBUTE foo bar>\n";

  // Create the stream reader.
  CefRefPtr<CefStreamReader> stream(
      CefStreamReader::CreateForData(test_str, sizeof(test_str) - 1));
  ASSERT_TRUE(stream.get() != NULL);

  // Create the XML reader.
  CefRefPtr<CefXmlReader> reader(
      CefXmlReader::Create(stream, XML_ENCODING_NONE,
      "http://www.example.org/example.xml"));
  ASSERT_TRUE(reader.get() != NULL);

  // Move to the processing instruction node and generate parser error.
  ASSERT_FALSE(reader->MoveToNextNode());
  ASSERT_TRUE(reader->HasError());
}

// Test XmlObject load behavior.
TEST(XmlReaderTest, ObjectLoad) {
  // Create the stream reader.
  CefRefPtr<CefStreamReader> stream(
      CefStreamReader::CreateForData(g_test_xml, sizeof(g_test_xml) - 1));
  ASSERT_TRUE(stream.get() != NULL);

  // Create the XML reader.
  CefRefPtr<CefXmlObject> object(new CefXmlObject("object"));
  ASSERT_TRUE(object->Load(stream, XML_ENCODING_NONE,
      "http://www.example.org/example.xml", NULL));

  ASSERT_FALSE(object->HasAttributes());
  ASSERT_TRUE(object->HasChildren());
  ASSERT_EQ(object->GetChildCount(), (size_t)1);

  CefRefPtr<CefXmlObject> obj(object->FindChild("ns:obj"));
  ASSERT_TRUE(obj.get());
  ASSERT_TRUE(obj->HasChildren());
  ASSERT_EQ(obj->GetChildCount(), (size_t)4);

  CefRefPtr<CefXmlObject> obj_child(obj->FindChild("ns:objC"));
  ASSERT_TRUE(obj_child.get());
  ASSERT_EQ(obj_child->GetName(), "ns:objC");
  ASSERT_FALSE(obj_child->HasChildren());
  ASSERT_FALSE(obj_child->HasValue());
  ASSERT_TRUE(obj_child->HasAttributes());

  CefXmlObject::ObjectVector obj_children;
  ASSERT_EQ(obj->GetChildren(obj_children), (size_t)4);
  ASSERT_EQ(obj_children.size(), (size_t)4);

  CefXmlObject::ObjectVector::const_iterator it = obj_children.begin();
  for (int ct = 0; it != obj_children.end(); ++it, ++ct) {
    obj_child = *it;
    ASSERT_TRUE(obj_child.get());
    if (ct == 0) {
      // ns:objA
      ASSERT_EQ(obj_child->GetName(), "ns:objA");
      ASSERT_FALSE(obj_child->HasChildren());
      ASSERT_TRUE(obj_child->HasValue());
      ASSERT_FALSE(obj_child->HasAttributes());
      ASSERT_EQ(obj_child->GetValue(), "value A");
    } else if (ct == 1) {
      // ns:objB
      ASSERT_EQ(obj_child->GetName(), "ns:objB");
      ASSERT_TRUE(obj_child->HasChildren());
      ASSERT_FALSE(obj_child->HasValue());
      ASSERT_FALSE(obj_child->HasAttributes());
      ASSERT_EQ(obj_child->GetChildCount(), (size_t)4);
      obj_child = obj_child->FindChild("ns:objB_4");
      ASSERT_TRUE(obj_child.get());
      ASSERT_TRUE(obj_child->HasValue());
      ASSERT_EQ(obj_child->GetValue(),
          "<b>this is</b> mixed content EA Value");
    } else if (ct == 2) {
      // ns:objC
      ASSERT_EQ(obj_child->GetName(), "ns:objC");
      ASSERT_FALSE(obj_child->HasChildren());
      ASSERT_FALSE(obj_child->HasValue());
      ASSERT_TRUE(obj_child->HasAttributes());

      CefXmlObject::AttributeMap attribs;
      ASSERT_EQ(obj_child->GetAttributes(attribs), (size_t)2);
      ASSERT_EQ(attribs.size(), (size_t)2);
      ASSERT_EQ(attribs["ns:attr1"], "value C1");
      ASSERT_EQ(attribs["ns:attr2"], "value C2");

      ASSERT_EQ(obj_child->GetAttributeCount(), (size_t)2);
      ASSERT_TRUE(obj_child->HasAttribute("ns:attr1"));
      ASSERT_EQ(obj_child->GetAttributeValue("ns:attr1"), "value C1");
      ASSERT_TRUE(obj_child->HasAttribute("ns:attr2"));
      ASSERT_EQ(obj_child->GetAttributeValue("ns:attr2"), "value C2");
    } else if (ct == 3) {
      // ns:objD
      ASSERT_EQ(obj_child->GetName(), "ns:objD");
      ASSERT_FALSE(obj_child->HasChildren());
      ASSERT_FALSE(obj_child->HasValue());
      ASSERT_FALSE(obj_child->HasAttributes());
    }
  }
}

// Test XmlObject load error handling behavior.
TEST(XmlReaderTest, ObjectLoadError) {
  // Test start/end tag mismatch error.
  {
    char error_xml[] = "<obj>\n<foo>\n</obj>\n</foo>";

    // Create the stream reader.
    CefRefPtr<CefStreamReader> stream(
        CefStreamReader::CreateForData(error_xml, sizeof(error_xml) - 1));
    ASSERT_TRUE(stream.get() != NULL);

    CefString error_str;

    // Create the XML reader.
    CefRefPtr<CefXmlObject> object(new CefXmlObject("object"));
    ASSERT_FALSE(object->Load(stream, XML_ENCODING_NONE,
        "http://www.example.org/example.xml", &error_str));
    ASSERT_EQ(error_str,
        "Opening and ending tag mismatch: foo line 2 and obj, line 3");
  }

  // Test value following child error.
  {
    char error_xml[] = "<obj>\n<foo>\n</foo>disallowed value\n</obj>";

    // Create the stream reader.
    CefRefPtr<CefStreamReader> stream(
        CefStreamReader::CreateForData(error_xml, sizeof(error_xml) - 1));
    ASSERT_TRUE(stream.get() != NULL);

    CefString error_str;

    // Create the XML reader.
    CefRefPtr<CefXmlObject> object(new CefXmlObject("object"));
    ASSERT_FALSE(object->Load(stream, XML_ENCODING_NONE,
        "http://www.example.org/example.xml", &error_str));
    ASSERT_EQ(error_str,
        "Value following child element, line 4");
  }
}
