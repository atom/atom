/*
 * Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
 * Copyright (C) 2006 Samuel Weinig <sam.weinig@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#import <WebKit/DOMObject.h>
#import <WebKit/DOMEventTarget.h>

#if WEBKIT_VERSION_MAX_ALLOWED >= WEBKIT_VERSION_1_3

@class DOMDocument;
@class DOMElement;
@class DOMNamedNodeMap;
@class DOMNode;
@class DOMNodeList;
@class NSString;

enum {
    DOM_ELEMENT_NODE = 1,
    DOM_ATTRIBUTE_NODE = 2,
    DOM_TEXT_NODE = 3,
    DOM_CDATA_SECTION_NODE = 4,
    DOM_ENTITY_REFERENCE_NODE = 5,
    DOM_ENTITY_NODE = 6,
    DOM_PROCESSING_INSTRUCTION_NODE = 7,
    DOM_COMMENT_NODE = 8,
    DOM_DOCUMENT_NODE = 9,
    DOM_DOCUMENT_TYPE_NODE = 10,
    DOM_DOCUMENT_FRAGMENT_NODE = 11,
    DOM_NOTATION_NODE = 12,
    DOM_DOCUMENT_POSITION_DISCONNECTED = 0x01,
    DOM_DOCUMENT_POSITION_PRECEDING = 0x02,
    DOM_DOCUMENT_POSITION_FOLLOWING = 0x04,
    DOM_DOCUMENT_POSITION_CONTAINS = 0x08,
    DOM_DOCUMENT_POSITION_CONTAINED_BY = 0x10,
    DOM_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = 0x20
};

@interface DOMNode : DOMObject <DOMEventTarget>
@property(readonly, copy) NSString *nodeName;
@property(copy) NSString *nodeValue;
@property(readonly) unsigned short nodeType;
@property(readonly, retain) DOMNode *parentNode;
@property(readonly, retain) DOMNodeList *childNodes;
@property(readonly, retain) DOMNode *firstChild;
@property(readonly, retain) DOMNode *lastChild;
@property(readonly, retain) DOMNode *previousSibling;
@property(readonly, retain) DOMNode *nextSibling;
@property(readonly, retain) DOMNamedNodeMap *attributes;
@property(readonly, retain) DOMDocument *ownerDocument;
@property(readonly, copy) NSString *namespaceURI;
@property(copy) NSString *prefix;
@property(readonly, copy) NSString *localName;
@property(readonly, copy) NSString *baseURI AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
@property(copy) NSString *textContent AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
@property(readonly, retain) DOMElement *parentElement AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
@property(readonly) BOOL isContentEditable AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;

- (DOMNode *)insertBefore:(DOMNode *)newChild refChild:(DOMNode *)refChild AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMNode *)replaceChild:(DOMNode *)newChild oldChild:(DOMNode *)oldChild AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMNode *)removeChild:(DOMNode *)oldChild;
- (DOMNode *)appendChild:(DOMNode *)newChild;
- (BOOL)hasChildNodes;
- (DOMNode *)cloneNode:(BOOL)deep;
- (void)normalize;
- (BOOL)isSupported:(NSString *)feature version:(NSString *)version AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (BOOL)hasAttributes;
- (BOOL)isSameNode:(DOMNode *)other AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (BOOL)isEqualNode:(DOMNode *)other AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (NSString *)lookupPrefix:(NSString *)namespaceURI AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (BOOL)isDefaultNamespace:(NSString *)namespaceURI AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (NSString *)lookupNamespaceURI:(NSString *)prefix AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (unsigned short)compareDocumentPosition:(DOMNode *)other AVAILABLE_IN_WEBKIT_VERSION_4_0;
- (BOOL)contains:(DOMNode *)other AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
@end

@interface DOMNode (DOMNodeDeprecated)
- (DOMNode *)insertBefore:(DOMNode *)newChild :(DOMNode *)refChild AVAILABLE_WEBKIT_VERSION_1_3_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0;
- (DOMNode *)replaceChild:(DOMNode *)newChild :(DOMNode *)oldChild AVAILABLE_WEBKIT_VERSION_1_3_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0;
- (BOOL)isSupported:(NSString *)feature :(NSString *)version AVAILABLE_WEBKIT_VERSION_1_3_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0;
@end

#endif
