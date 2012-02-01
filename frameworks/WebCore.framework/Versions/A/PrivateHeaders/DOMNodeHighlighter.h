/*
 * Copyright (C) 2011 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef DOMNodeHighlighter_h
#define DOMNodeHighlighter_h

#include "Color.h"
#include "FloatQuad.h"

#include <wtf/OwnPtr.h>
#include <wtf/RefPtr.h>
#include <wtf/Vector.h>

namespace WebCore {

class Color;
class Document;
class GraphicsContext;
class IntRect;
class Node;

struct HighlightData {
    Color content;
    Color contentOutline;
    Color padding;
    Color border;
    Color margin;
    bool showInfo;

    // Either of these must be 0.
    RefPtr<Node> node;
    OwnPtr<IntRect> rect;
};

enum HighlightType {
    HighlightTypeNode,
    HighlightTypeRects,
};

struct Highlight {
    Color contentColor;
    Color paddingColor;
    Color borderColor;
    Color marginColor;

    // When the type is Node, there are 4 quads (margin, border, padding, content).
    // When the type is Rects, this is just a list of quads.
    HighlightType type;
    Vector<FloatQuad> quads;
};

namespace DOMNodeHighlighter {

void drawHighlight(GraphicsContext&, Document*, HighlightData*);
void getHighlight(Document*, HighlightData*, Highlight*);

} // namespace DOMNodeHighlighter

} // namespace WebCore


#endif // DOMNodeHighlighter_h
