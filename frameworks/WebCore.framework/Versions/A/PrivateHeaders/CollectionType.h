/*
 * Copyright (C) 1999 Lars Knoll (knoll@kde.org)
 *           (C) 1999 Antti Koivisto (koivisto@kde.org)
 * Copyright (C) 2003, 2004, 2005, 2006, 2007, 2008 Apple Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 */

#ifndef CollectionType_h
#define CollectionType_h

namespace WebCore {

enum CollectionType {
    // unnamed collection types cached in the document

    DocImages,    // all <img> elements in the document
    DocApplets,   // all <object> and <applet> elements
    DocEmbeds,    // all <embed> elements
    DocObjects,   // all <object> elements
    DocForms,     // all <form> elements
    DocLinks,     // all <a> _and_ <area> elements with a value for href
    DocAnchors,   // all <a> elements with a value for name
    DocScripts,   // all <script> elements

    DocAll,       // "all" elements (IE)

    // named collection types cached in the document

    WindowNamedItems,
    DocumentNamedItems,

    // types not cached in the document; these are types that can't be used on a document

    NodeChildren, // first-level children (IE)
    TableTBodies, // all <tbody> elements in this table
    TSectionRows, // all row elements in this table section
    TRCells,      // all cells in this row
    SelectOptions,
    DataListOptions,
    MapAreas,

#if ENABLE(MICRODATA)
    ItemProperties, // Microdata item properties in the document
#endif

    OtherCollection
};

static const CollectionType FirstUnnamedDocumentCachedType = DocImages;
static const unsigned NumUnnamedDocumentCachedTypes = WindowNamedItems - DocImages + 1;

static const CollectionType FirstNodeCollectionType = NodeChildren;
static const unsigned NumNodeCollectionTypes = OtherCollection - NodeChildren + 1;

} // namespace

#endif
