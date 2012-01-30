/*
 * Copyright (C) 2000 Lars Knoll (knoll@kde.org)
 *           (C) 2000 Antti Koivisto (koivisto@kde.org)
 *           (C) 2000 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2003, 2005, 2006, 2007, 2008 Apple Inc. All rights reserved.
 * Copyright (C) 2006 Graham Dennis (graham.dennis@gmail.com)
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

#ifndef FillLayer_h
#define FillLayer_h

#include "GraphicsTypes.h"
#include "Length.h"
#include "LengthSize.h"
#include "RenderStyleConstants.h"
#include "StyleImage.h"
#include <wtf/RefPtr.h>

namespace WebCore {

struct FillSize {
    FillSize()
        : type(SizeLength)
    {
    }

    FillSize(EFillSizeType t, LengthSize l)
        : type(t)
        , size(l)
    {
    }

    bool operator==(const FillSize& o) const
    {
        return type == o.type && size == o.size;
    }
    bool operator!=(const FillSize& o) const
    {
        return !(*this == o);
    }

    EFillSizeType type;
    LengthSize size;
};

class FillLayer {
    WTF_MAKE_FAST_ALLOCATED;
public:
    FillLayer(EFillLayerType);
    ~FillLayer();

    StyleImage* image() const { return m_image.get(); }
    Length xPosition() const { return m_xPosition; }
    Length yPosition() const { return m_yPosition; }
    EFillAttachment attachment() const { return static_cast<EFillAttachment>(m_attachment); }
    EFillBox clip() const { return static_cast<EFillBox>(m_clip); }
    EFillBox origin() const { return static_cast<EFillBox>(m_origin); }
    EFillRepeat repeatX() const { return static_cast<EFillRepeat>(m_repeatX); }
    EFillRepeat repeatY() const { return static_cast<EFillRepeat>(m_repeatY); }
    CompositeOperator composite() const { return static_cast<CompositeOperator>(m_composite); }
    LengthSize sizeLength() const { return m_sizeLength; }
    EFillSizeType sizeType() const { return static_cast<EFillSizeType>(m_sizeType); }
    FillSize size() const { return FillSize(static_cast<EFillSizeType>(m_sizeType), m_sizeLength); }

    const FillLayer* next() const { return m_next; }
    FillLayer* next() { return m_next; }

    bool isImageSet() const { return m_imageSet; }
    bool isXPositionSet() const { return m_xPosSet; }
    bool isYPositionSet() const { return m_yPosSet; }
    bool isAttachmentSet() const { return m_attachmentSet; }
    bool isClipSet() const { return m_clipSet; }
    bool isOriginSet() const { return m_originSet; }
    bool isRepeatXSet() const { return m_repeatXSet; }
    bool isRepeatYSet() const { return m_repeatYSet; }
    bool isCompositeSet() const { return m_compositeSet; }
    bool isSizeSet() const { return m_sizeType != SizeNone; }
    
    void setImage(PassRefPtr<StyleImage> i) { m_image = i; m_imageSet = true; }
    void setXPosition(Length l) { m_xPosition = l; m_xPosSet = true; }
    void setYPosition(Length l) { m_yPosition = l; m_yPosSet = true; }
    void setAttachment(EFillAttachment attachment) { m_attachment = attachment; m_attachmentSet = true; }
    void setClip(EFillBox b) { m_clip = b; m_clipSet = true; }
    void setOrigin(EFillBox b) { m_origin = b; m_originSet = true; }
    void setRepeatX(EFillRepeat r) { m_repeatX = r; m_repeatXSet = true; }
    void setRepeatY(EFillRepeat r) { m_repeatY = r; m_repeatYSet = true; }
    void setComposite(CompositeOperator c) { m_composite = c; m_compositeSet = true; }
    void setSizeType(EFillSizeType b) { m_sizeType = b; }
    void setSizeLength(LengthSize l) { m_sizeLength = l; }
    void setSize(FillSize f) { m_sizeType = f.type; m_sizeLength = f.size; }
    
    void clearImage() { m_image.clear(); m_imageSet = false; }
    void clearXPosition() { m_xPosSet = false; }
    void clearYPosition() { m_yPosSet = false; }
    void clearAttachment() { m_attachmentSet = false; }
    void clearClip() { m_clipSet = false; }
    void clearOrigin() { m_originSet = false; }
    void clearRepeatX() { m_repeatXSet = false; }
    void clearRepeatY() { m_repeatYSet = false; }
    void clearComposite() { m_compositeSet = false; }
    void clearSize() { m_sizeType = SizeNone; }

    void setNext(FillLayer* n) { if (m_next != n) { delete m_next; m_next = n; } }

    FillLayer& operator=(const FillLayer& o);    
    FillLayer(const FillLayer& o);

    bool operator==(const FillLayer& o) const;
    bool operator!=(const FillLayer& o) const
    {
        return !(*this == o);
    }

    bool containsImage(StyleImage*) const;
    bool imagesAreLoaded() const;

    bool hasImage() const
    {
        if (m_image)
            return true;
        return m_next ? m_next->hasImage() : false;
    }

    bool hasFixedImage() const
    {
        if (m_image && m_attachment == FixedBackgroundAttachment)
            return true;
        return m_next ? m_next->hasFixedImage() : false;
    }

    EFillLayerType type() const { return static_cast<EFillLayerType>(m_type); }

    void fillUnsetProperties();
    void cullEmptyLayers();

    static EFillAttachment initialFillAttachment(EFillLayerType) { return ScrollBackgroundAttachment; }
    static EFillBox initialFillClip(EFillLayerType) { return BorderFillBox; }
    static EFillBox initialFillOrigin(EFillLayerType type) { return type == BackgroundFillLayer ? PaddingFillBox : BorderFillBox; }
    static EFillRepeat initialFillRepeatX(EFillLayerType) { return RepeatFill; }
    static EFillRepeat initialFillRepeatY(EFillLayerType) { return RepeatFill; }
    static CompositeOperator initialFillComposite(EFillLayerType) { return CompositeSourceOver; }
    static EFillSizeType initialFillSizeType(EFillLayerType) { return SizeLength; }
    static LengthSize initialFillSizeLength(EFillLayerType) { return LengthSize(); }
    static FillSize initialFillSize(EFillLayerType) { return FillSize(); }
    static Length initialFillXPosition(EFillLayerType) { return Length(0.0, Percent); }
    static Length initialFillYPosition(EFillLayerType) { return Length(0.0, Percent); }
    static StyleImage* initialFillImage(EFillLayerType) { return 0; }

private:
    friend class RenderStyle;

    FillLayer() { }

    FillLayer* m_next;

    RefPtr<StyleImage> m_image;

    Length m_xPosition;
    Length m_yPosition;

    unsigned m_attachment : 2; // EFillAttachment
    unsigned m_clip : 2; // EFillBox
    unsigned m_origin : 2; // EFillBox
    unsigned m_repeatX : 3; // EFillRepeat
    unsigned m_repeatY : 3; // EFillRepeat
    unsigned m_composite : 4; // CompositeOperator
    unsigned m_sizeType : 2; // EFillSizeType
    
    LengthSize m_sizeLength;

    bool m_imageSet : 1;
    bool m_attachmentSet : 1;
    bool m_clipSet : 1;
    bool m_originSet : 1;
    bool m_repeatXSet : 1;
    bool m_repeatYSet : 1;
    bool m_xPosSet : 1;
    bool m_yPosSet : 1;
    bool m_compositeSet : 1;
    
    unsigned m_type : 1; // EFillLayerType
};

} // namespace WebCore

#endif // FillLayer_h
