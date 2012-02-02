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

#import <WebKit/DOMNode.h>

#if WEBKIT_VERSION_MAX_ALLOWED >= WEBKIT_VERSION_1_3

@class DOMAbstractView;
@class DOMAttr;
@class DOMCDATASection;
@class DOMCSSRuleList;
@class DOMCSSStyleDeclaration;
@class DOMComment;
@class DOMDocumentFragment;
@class DOMDocumentType;
@class DOMElement;
@class DOMEntityReference;
@class DOMEvent;
@class DOMHTMLCollection;
@class DOMHTMLElement;
@class DOMImplementation;
@class DOMNode;
@class DOMNodeIterator;
@class DOMNodeList;
@class DOMProcessingInstruction;
@class DOMRange;
@class DOMStyleSheetList;
@class DOMText;
@class DOMTreeWalker;
@class DOMXPathExpression;
@class DOMXPathResult;
@class NSString;
@protocol DOMNodeFilter;
@protocol DOMXPathNSResolver;

@interface DOMDocument : DOMNode
@property(readonly, retain) DOMDocumentType *doctype;
@property(readonly, retain) DOMImplementation *implementation;
@property(readonly, retain) DOMElement *documentElement;
@property(readonly, copy) NSString *inputEncoding AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
@property(readonly, copy) NSString *xmlEncoding AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
@property(copy) NSString *xmlVersion AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
@property BOOL xmlStandalone AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
@property(copy) NSString *documentURI AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
@property(readonly, retain) DOMAbstractView *defaultView;
@property(readonly, retain) DOMStyleSheetList *styleSheets;
@property(copy) NSString *title;
@property(readonly, copy) NSString *referrer;
@property(readonly, copy) NSString *domain;
@property(readonly, copy) NSString *URL;
@property(copy) NSString *cookie;
@property(retain) DOMHTMLElement *body;
@property(readonly, retain) DOMHTMLCollection *images;
@property(readonly, retain) DOMHTMLCollection *applets;
@property(readonly, retain) DOMHTMLCollection *links;
@property(readonly, retain) DOMHTMLCollection *forms;
@property(readonly, retain) DOMHTMLCollection *anchors;
@property(readonly, copy) NSString *lastModified AVAILABLE_IN_WEBKIT_VERSION_4_0;
@property(copy) NSString *charset AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
@property(readonly, copy) NSString *defaultCharset AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
@property(readonly, copy) NSString *readyState AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
@property(readonly, copy) NSString *characterSet AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
@property(readonly, copy) NSString *preferredStylesheetSet AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
@property(copy) NSString *selectedStylesheetSet AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;

- (DOMElement *)createElement:(NSString *)tagName;
- (DOMDocumentFragment *)createDocumentFragment;
- (DOMText *)createTextNode:(NSString *)data;
- (DOMComment *)createComment:(NSString *)data;
- (DOMCDATASection *)createCDATASection:(NSString *)data;
- (DOMProcessingInstruction *)createProcessingInstruction:(NSString *)target data:(NSString *)data AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMAttr *)createAttribute:(NSString *)name;
- (DOMEntityReference *)createEntityReference:(NSString *)name;
- (DOMNodeList *)getElementsByTagName:(NSString *)tagname;
- (DOMNode *)importNode:(DOMNode *)importedNode deep:(BOOL)deep AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMElement *)createElementNS:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMAttr *)createAttributeNS:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMNodeList *)getElementsByTagNameNS:(NSString *)namespaceURI localName:(NSString *)localName AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMElement *)getElementById:(NSString *)elementId;
- (DOMNode *)adoptNode:(DOMNode *)source AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMEvent *)createEvent:(NSString *)eventType;
- (DOMRange *)createRange;
- (DOMNodeIterator *)createNodeIterator:(DOMNode *)root whatToShow:(unsigned)whatToShow filter:(id <DOMNodeFilter>)filter expandEntityReferences:(BOOL)expandEntityReferences AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMTreeWalker *)createTreeWalker:(DOMNode *)root whatToShow:(unsigned)whatToShow filter:(id <DOMNodeFilter>)filter expandEntityReferences:(BOOL)expandEntityReferences AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMCSSStyleDeclaration *)getOverrideStyle:(DOMElement *)element pseudoElement:(NSString *)pseudoElement AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMXPathExpression *)createExpression:(NSString *)expression resolver:(id <DOMXPathNSResolver>)resolver AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (id <DOMXPathNSResolver>)createNSResolver:(DOMNode *)nodeResolver AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMXPathResult *)evaluate:(NSString *)expression contextNode:(DOMNode *)contextNode resolver:(id <DOMXPathNSResolver>)resolver type:(unsigned short)type inResult:(DOMXPathResult *)inResult AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (BOOL)execCommand:(NSString *)command userInterface:(BOOL)userInterface value:(NSString *)value AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (BOOL)execCommand:(NSString *)command userInterface:(BOOL)userInterface AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (BOOL)execCommand:(NSString *)command AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (BOOL)queryCommandEnabled:(NSString *)command AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (BOOL)queryCommandIndeterm:(NSString *)command AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (BOOL)queryCommandState:(NSString *)command AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (BOOL)queryCommandSupported:(NSString *)command AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (NSString *)queryCommandValue:(NSString *)command AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMNodeList *)getElementsByName:(NSString *)elementName;
- (DOMElement *)elementFromPoint:(int)x y:(int)y AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMCSSStyleDeclaration *)createCSSStyleDeclaration AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMCSSStyleDeclaration *)getComputedStyle:(DOMElement *)element pseudoElement:(NSString *)pseudoElement AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMCSSRuleList *)getMatchedCSSRules:(DOMElement *)element pseudoElement:(NSString *)pseudoElement AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMCSSRuleList *)getMatchedCSSRules:(DOMElement *)element pseudoElement:(NSString *)pseudoElement authorOnly:(BOOL)authorOnly AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER;
- (DOMNodeList *)getElementsByClassName:(NSString *)tagname AVAILABLE_IN_WEBKIT_VERSION_4_0;
- (DOMElement *)querySelector:(NSString *)selectors AVAILABLE_IN_WEBKIT_VERSION_4_0;
- (DOMNodeList *)querySelectorAll:(NSString *)selectors AVAILABLE_IN_WEBKIT_VERSION_4_0;
- (void)webkitCancelFullScreen AVAILABLE_IN_WEBKIT_VERSION_4_0;
@end

@interface DOMDocument (DOMDocumentDeprecated)
- (DOMProcessingInstruction *)createProcessingInstruction:(NSString *)target :(NSString *)data AVAILABLE_WEBKIT_VERSION_1_3_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0;
- (DOMNode *)importNode:(DOMNode *)importedNode :(BOOL)deep AVAILABLE_WEBKIT_VERSION_1_3_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0;
- (DOMElement *)createElementNS:(NSString *)namespaceURI :(NSString *)qualifiedName AVAILABLE_WEBKIT_VERSION_1_3_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0;
- (DOMAttr *)createAttributeNS:(NSString *)namespaceURI :(NSString *)qualifiedName AVAILABLE_WEBKIT_VERSION_1_3_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0;
- (DOMNodeList *)getElementsByTagNameNS:(NSString *)namespaceURI :(NSString *)localName AVAILABLE_WEBKIT_VERSION_1_3_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0;
- (DOMNodeIterator *)createNodeIterator:(DOMNode *)root :(unsigned)whatToShow :(id <DOMNodeFilter>)filter :(BOOL)expandEntityReferences AVAILABLE_WEBKIT_VERSION_1_3_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0;
- (DOMTreeWalker *)createTreeWalker:(DOMNode *)root :(unsigned)whatToShow :(id <DOMNodeFilter>)filter :(BOOL)expandEntityReferences AVAILABLE_WEBKIT_VERSION_1_3_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0;
- (DOMCSSStyleDeclaration *)getOverrideStyle:(DOMElement *)element :(NSString *)pseudoElement AVAILABLE_WEBKIT_VERSION_1_3_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0;
- (DOMXPathExpression *)createExpression:(NSString *)expression :(id <DOMXPathNSResolver>)resolver AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER_BUT_DEPRECATED;
- (DOMXPathResult *)evaluate:(NSString *)expression :(DOMNode *)contextNode :(id <DOMXPathNSResolver>)resolver :(unsigned short)type :(DOMXPathResult *)inResult AVAILABLE_WEBKIT_VERSION_3_0_AND_LATER_BUT_DEPRECATED;
- (DOMCSSStyleDeclaration *)getComputedStyle:(DOMElement *)element :(NSString *)pseudoElement AVAILABLE_WEBKIT_VERSION_1_3_AND_LATER_BUT_DEPRECATED_IN_WEBKIT_VERSION_3_0;
@end

#endif
