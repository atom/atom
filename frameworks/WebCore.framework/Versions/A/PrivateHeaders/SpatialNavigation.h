/*
 * Copyright (C) 2009 Nokia Corporation and/or its subsidiary(-ies)
 * Copyright (C) 2009 Antonio Gomes <tonikitoo@webkit.org>
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
 */

#ifndef SpatialNavigation_h
#define SpatialNavigation_h

#include "FocusDirection.h"
#include "HTMLFrameOwnerElement.h"
#include "LayoutTypes.h"
#include "Node.h"

#include <limits>

namespace WebCore {

class Element;
class Frame;
class HTMLAreaElement;
class IntRect;
class RenderObject;

using namespace std;

inline long long maxDistance()
{
    return numeric_limits<long long>::max();
}

inline int fudgeFactor()
{
    return 2;
}

bool isSpatialNavigationEnabled(const Frame*);

// Spatially speaking, two given elements in a web page can be:
// 1) Fully aligned: There is a full intersection between the rects, either
//    vertically or horizontally.
//
// * Horizontally       * Vertically
//    _
//   |_|                   _ _ _ _ _ _
//   |_|...... _          |_|_|_|_|_|_|
//   |_|      |_|         .       .
//   |_|......|_|   OR    .       .
//   |_|      |_|         .       .
//   |_|......|_|          _ _ _ _
//   |_|                  |_|_|_|_|
//
//
// 2) Partially aligned: There is a partial intersection between the rects, either
//    vertically or horizontally.
//
// * Horizontally       * Vertically
//    _                   _ _ _ _ _
//   |_|                 |_|_|_|_|_|
//   |_|.... _      OR           . .
//   |_|    |_|                  . .
//   |_|....|_|                  ._._ _
//          |_|                  |_|_|_|
//          |_|
//
// 3) Or, otherwise, not aligned at all.
//
// * Horizontally       * Vertically
//         _              _ _ _ _
//        |_|            |_|_|_|_|
//        |_|                    .
//        |_|                     .
//       .          OR             .
//    _ .                           ._ _ _ _ _
//   |_|                            |_|_|_|_|_|
//   |_|
//   |_|
//
// "Totally Aligned" elements are preferable candidates to move
// focus to over "Partially Aligned" ones, that on its turns are
// more preferable than "Not Aligned".
enum RectsAlignment {
    None = 0,
    Partial,
    Full
};

struct FocusCandidate {
    FocusCandidate()
        : visibleNode(0)
        , focusableNode(0)
        , enclosingScrollableBox(0)
        , distance(maxDistance())
        , parentDistance(maxDistance())
        , alignment(None)
        , parentAlignment(None)
        , isOffscreen(true)
        , isOffscreenAfterScrolling(true)
    {
    }

    FocusCandidate(Node* n, FocusDirection);
    explicit FocusCandidate(HTMLAreaElement* area, FocusDirection);
    bool isNull() const { return !visibleNode; }
    bool inScrollableContainer() const { return visibleNode && enclosingScrollableBox; }
    bool isFrameOwnerElement() const { return visibleNode && visibleNode->isFrameOwnerElement(); }
    Document* document() const { return visibleNode ? visibleNode->document() : 0; }

    // We handle differently visibleNode and FocusableNode to properly handle the areas of imagemaps,
    // where visibleNode would represent the image element and focusableNode would represent the area element.
    // In all other cases, visibleNode and focusableNode are one and the same.
    Node* visibleNode;
    Node* focusableNode;
    Node* enclosingScrollableBox;
    long long distance;
    long long parentDistance;
    RectsAlignment alignment;
    RectsAlignment parentAlignment;
    LayoutRect rect;
    bool isOffscreen;
    bool isOffscreenAfterScrolling;
};

bool hasOffscreenRect(Node*, FocusDirection direction = FocusDirectionNone);
bool scrollInDirection(Frame*, FocusDirection);
bool scrollInDirection(Node* container, FocusDirection);
bool canScrollInDirection(const Node* container, FocusDirection);
bool canScrollInDirection(const Frame*, FocusDirection);
bool canBeScrolledIntoView(FocusDirection, const FocusCandidate&);
bool areElementsOnSameLine(const FocusCandidate& firstCandidate, const FocusCandidate& secondCandidate);
void distanceDataForNode(FocusDirection, const FocusCandidate& current, FocusCandidate& candidate);
Node* scrollableEnclosingBoxOrParentFrameForNodeInDirection(FocusDirection, Node*);
LayoutRect nodeRectInAbsoluteCoordinates(Node*, bool ignoreBorder = false);
LayoutRect frameRectInAbsoluteCoordinates(Frame*);
LayoutRect virtualRectForDirection(FocusDirection, const LayoutRect& startingRect, LayoutUnit width = 0);
LayoutRect virtualRectForAreaElementAndDirection(HTMLAreaElement*, FocusDirection);
HTMLFrameOwnerElement* frameOwnerElement(FocusCandidate&);

} // namspace WebCore

#endif // SpatialNavigation_h
