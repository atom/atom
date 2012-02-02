/*
 * Copyright (C) 2007 Alp Toker <alp@atoker.com>
 * Copyright (C) 2007 Apple Inc.
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

#ifndef PrintContext_h
#define PrintContext_h

#include <wtf/Forward.h>
#include <wtf/Vector.h>

namespace WebCore {

class Element;
class Frame;
class FloatRect;
class FloatSize;
class GraphicsContext;
class IntRect;

class PrintContext {
public:
    PrintContext(Frame*);
    ~PrintContext();

    Frame* frame() const { return m_frame; }

    // Break up a page into rects without relayout.
    // FIXME: This means that CSS page breaks won't be on page boundary if the size is different than what was passed to begin(). That's probably not always desirable.
    // FIXME: Header and footer height should be applied before layout, not after.
    // FIXME: The printRect argument is only used to determine page aspect ratio, it would be better to pass a FloatSize with page dimensions instead.
    void computePageRects(const FloatRect& printRect, float headerHeight, float footerHeight, float userScaleFactor, float& outPageHeight, bool allowHorizontalTiling = false);

    // Deprecated. Page size computation is already in this class, clients shouldn't be copying it.
    void computePageRectsWithPageSize(const FloatSize& pageSizeInPixels, bool allowHorizontalTiling);

    // These are only valid after page rects are computed.
    size_t pageCount() const { return m_pageRects.size(); }
    const IntRect& pageRect(size_t pageNumber) const { return m_pageRects[pageNumber]; }
    const Vector<IntRect>& pageRects() const { return m_pageRects; }

    float computeAutomaticScaleFactor(const FloatSize& availablePaperSize);

    // Enter print mode, updating layout for new page size.
    // This function can be called multiple times to apply new print options without going back to screen mode.
    void begin(float width, float height = 0);

    // FIXME: eliminate width argument.
    void spoolPage(GraphicsContext& ctx, int pageNumber, float width);

    void spoolRect(GraphicsContext& ctx, const IntRect&);

    // Return to screen mode.
    void end();

    // Used by layout tests.
    static int pageNumberForElement(Element*, const FloatSize& pageSizeInPixels); // Returns -1 if page isn't found.
    static String pageProperty(Frame* frame, const char* propertyName, int pageNumber);
    static bool isPageBoxVisible(Frame* frame, int pageNumber);
    static String pageSizeAndMarginsInPixels(Frame* frame, int pageNumber, int width, int height, int marginTop, int marginRight, int marginBottom, int marginLeft);
    static int numberOfPages(Frame*, const FloatSize& pageSizeInPixels);
    // Draw all pages into a graphics context with lines which mean page boundaries.
    // The height of the graphics context should be
    // (pageSizeInPixels.height() + 1) * number-of-pages - 1
    static void spoolAllPagesWithBoundaries(Frame*, GraphicsContext&, const FloatSize& pageSizeInPixels);

protected:
    Frame* m_frame;
    Vector<IntRect> m_pageRects;

private:
    void computePageRectsWithPageSizeInternal(const FloatSize& pageSizeInPixels, bool allowHorizontalTiling);

    // Used to prevent misuses of begin() and end() (e.g., call end without begin).
    bool m_isPrinting;
};

}

#endif
