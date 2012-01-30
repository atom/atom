/*
 * Copyright (C) 2006, 2007, 2009 Apple Inc. All rights reserved.
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

#ifndef HTMLFrameOwnerElement_h
#define HTMLFrameOwnerElement_h

#include "FrameLoaderTypes.h"
#include "HTMLElement.h"

namespace WebCore {

class DOMWindow;
class Frame;
class RenderPart;

#if ENABLE(SVG)
class SVGDocument;
#endif

class HTMLFrameOwnerElement : public HTMLElement {
public:
    virtual ~HTMLFrameOwnerElement();

    Frame* contentFrame() const { return m_contentFrame; }
    DOMWindow* contentWindow() const;
    Document* contentDocument() const;

    // Most subclasses use RenderPart (either RenderEmbeddedObject or RenderIFrame)
    // except for HTMLObjectElement and HTMLEmbedElement which may return any
    // RenderObject when using fallback content.
    RenderPart* renderPart() const;

#if ENABLE(SVG)
    SVGDocument* getSVGDocument(ExceptionCode&) const;
#endif

    virtual ScrollbarMode scrollingMode() const { return ScrollbarAuto; }

    SandboxFlags sandboxFlags() const { return m_sandboxFlags; }

protected:
    HTMLFrameOwnerElement(const QualifiedName& tagName, Document*);

    void setSandboxFlags(SandboxFlags);

    virtual void willRemove();

private:
    friend class Frame;

    virtual bool isFrameOwnerElement() const { return true; }
    virtual bool isKeyboardFocusable(KeyboardEvent*) const;

    Frame* m_contentFrame;
    SandboxFlags m_sandboxFlags;
};

} // namespace WebCore

#endif // HTMLFrameOwnerElement_h
