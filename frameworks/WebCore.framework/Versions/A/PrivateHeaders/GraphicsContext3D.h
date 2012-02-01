/*
 * Copyright (C) 2009 Apple Inc. All rights reserved.
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

#ifndef GraphicsContext3D_h
#define GraphicsContext3D_h

#include "IntSize.h"
#include "GraphicsLayer.h"
#include "GraphicsTypes3D.h"
#include "PlatformString.h"

#include <wtf/HashMap.h>
#include <wtf/ListHashSet.h>
#include <wtf/Noncopyable.h>

// FIXME: Find a better way to avoid the name confliction for NO_ERROR.
#if ((PLATFORM(CHROMIUM) && OS(WINDOWS)) || PLATFORM(WIN) || (PLATFORM(QT) && OS(WINDOWS)))
#undef NO_ERROR
#elif PLATFORM(GTK)
// This define is from the X11 headers, but it's used below, so we must undefine it.
#undef VERSION
#endif

#if PLATFORM(MAC) || PLATFORM(GTK) || PLATFORM(QT)
#include "ANGLEWebKitBridge.h"
#endif

#if PLATFORM(MAC)
#include <OpenGL/OpenGL.h>
#include <wtf/RetainPtr.h>
OBJC_CLASS CALayer;
OBJC_CLASS WebGLLayer;
#elif PLATFORM(QT)
QT_BEGIN_NAMESPACE
class QPainter;
class QRect;
QT_END_NAMESPACE
#elif PLATFORM(GTK)
typedef unsigned int GLuint;
#endif

#if PLATFORM(MAC)
typedef CGLContextObj PlatformGraphicsContext3D;
#else
typedef void* PlatformGraphicsContext3D;
#endif

#if PLATFORM(CHROMIUM) && USE(SKIA)
class GrContext;
#endif

// These are currently the same among all implementations.
const PlatformGraphicsContext3D NullPlatformGraphicsContext3D = 0;
const Platform3DObject NullPlatform3DObject = 0;

#if USE(CG)
#include <CoreGraphics/CGContext.h>
#endif

namespace WebCore {
class CanvasRenderingContext;
class DrawingBuffer;
class Extensions3D;
#if PLATFORM(MAC) || PLATFORM(GTK) || PLATFORM(QT)
class Extensions3DOpenGL;
#endif
#if PLATFORM(QT)
class Extensions3DQt;
#endif
class HostWindow;
class Image;
class ImageBuffer;
class ImageData;
#if USE(CAIRO)
class PlatformContextCairo;
#endif

struct ActiveInfo {
    String name;
    GC3Denum type;
    GC3Dint size;
};

class GraphicsContext3DPrivate;

class GraphicsContext3D : public RefCounted<GraphicsContext3D> {
public:
    enum {
        DEPTH_BUFFER_BIT = 0x00000100,
        STENCIL_BUFFER_BIT = 0x00000400,
        COLOR_BUFFER_BIT = 0x00004000,
        POINTS = 0x0000,
        LINES = 0x0001,
        LINE_LOOP = 0x0002,
        LINE_STRIP = 0x0003,
        TRIANGLES = 0x0004,
        TRIANGLE_STRIP = 0x0005,
        TRIANGLE_FAN = 0x0006,
        ZERO = 0,
        ONE = 1,
        SRC_COLOR = 0x0300,
        ONE_MINUS_SRC_COLOR = 0x0301,
        SRC_ALPHA = 0x0302,
        ONE_MINUS_SRC_ALPHA = 0x0303,
        DST_ALPHA = 0x0304,
        ONE_MINUS_DST_ALPHA = 0x0305,
        DST_COLOR = 0x0306,
        ONE_MINUS_DST_COLOR = 0x0307,
        SRC_ALPHA_SATURATE = 0x0308,
        FUNC_ADD = 0x8006,
        BLEND_EQUATION = 0x8009,
        BLEND_EQUATION_RGB = 0x8009,
        BLEND_EQUATION_ALPHA = 0x883D,
        FUNC_SUBTRACT = 0x800A,
        FUNC_REVERSE_SUBTRACT = 0x800B,
        BLEND_DST_RGB = 0x80C8,
        BLEND_SRC_RGB = 0x80C9,
        BLEND_DST_ALPHA = 0x80CA,
        BLEND_SRC_ALPHA = 0x80CB,
        CONSTANT_COLOR = 0x8001,
        ONE_MINUS_CONSTANT_COLOR = 0x8002,
        CONSTANT_ALPHA = 0x8003,
        ONE_MINUS_CONSTANT_ALPHA = 0x8004,
        BLEND_COLOR = 0x8005,
        ARRAY_BUFFER = 0x8892,
        ELEMENT_ARRAY_BUFFER = 0x8893,
        ARRAY_BUFFER_BINDING = 0x8894,
        ELEMENT_ARRAY_BUFFER_BINDING = 0x8895,
        STREAM_DRAW = 0x88E0,
        STATIC_DRAW = 0x88E4,
        DYNAMIC_DRAW = 0x88E8,
        BUFFER_SIZE = 0x8764,
        BUFFER_USAGE = 0x8765,
        CURRENT_VERTEX_ATTRIB = 0x8626,
        FRONT = 0x0404,
        BACK = 0x0405,
        FRONT_AND_BACK = 0x0408,
        TEXTURE_2D = 0x0DE1,
        CULL_FACE = 0x0B44,
        BLEND = 0x0BE2,
        DITHER = 0x0BD0,
        STENCIL_TEST = 0x0B90,
        DEPTH_TEST = 0x0B71,
        SCISSOR_TEST = 0x0C11,
        POLYGON_OFFSET_FILL = 0x8037,
        SAMPLE_ALPHA_TO_COVERAGE = 0x809E,
        SAMPLE_COVERAGE = 0x80A0,
        NO_ERROR = 0,
        INVALID_ENUM = 0x0500,
        INVALID_VALUE = 0x0501,
        INVALID_OPERATION = 0x0502,
        OUT_OF_MEMORY = 0x0505,
        CW = 0x0900,
        CCW = 0x0901,
        LINE_WIDTH = 0x0B21,
        ALIASED_POINT_SIZE_RANGE = 0x846D,
        ALIASED_LINE_WIDTH_RANGE = 0x846E,
        CULL_FACE_MODE = 0x0B45,
        FRONT_FACE = 0x0B46,
        DEPTH_RANGE = 0x0B70,
        DEPTH_WRITEMASK = 0x0B72,
        DEPTH_CLEAR_VALUE = 0x0B73,
        DEPTH_FUNC = 0x0B74,
        STENCIL_CLEAR_VALUE = 0x0B91,
        STENCIL_FUNC = 0x0B92,
        STENCIL_FAIL = 0x0B94,
        STENCIL_PASS_DEPTH_FAIL = 0x0B95,
        STENCIL_PASS_DEPTH_PASS = 0x0B96,
        STENCIL_REF = 0x0B97,
        STENCIL_VALUE_MASK = 0x0B93,
        STENCIL_WRITEMASK = 0x0B98,
        STENCIL_BACK_FUNC = 0x8800,
        STENCIL_BACK_FAIL = 0x8801,
        STENCIL_BACK_PASS_DEPTH_FAIL = 0x8802,
        STENCIL_BACK_PASS_DEPTH_PASS = 0x8803,
        STENCIL_BACK_REF = 0x8CA3,
        STENCIL_BACK_VALUE_MASK = 0x8CA4,
        STENCIL_BACK_WRITEMASK = 0x8CA5,
        VIEWPORT = 0x0BA2,
        SCISSOR_BOX = 0x0C10,
        COLOR_CLEAR_VALUE = 0x0C22,
        COLOR_WRITEMASK = 0x0C23,
        UNPACK_ALIGNMENT = 0x0CF5,
        PACK_ALIGNMENT = 0x0D05,
        MAX_TEXTURE_SIZE = 0x0D33,
        MAX_VIEWPORT_DIMS = 0x0D3A,
        SUBPIXEL_BITS = 0x0D50,
        RED_BITS = 0x0D52,
        GREEN_BITS = 0x0D53,
        BLUE_BITS = 0x0D54,
        ALPHA_BITS = 0x0D55,
        DEPTH_BITS = 0x0D56,
        STENCIL_BITS = 0x0D57,
        POLYGON_OFFSET_UNITS = 0x2A00,
        POLYGON_OFFSET_FACTOR = 0x8038,
        TEXTURE_BINDING_2D = 0x8069,
        SAMPLE_BUFFERS = 0x80A8,
        SAMPLES = 0x80A9,
        SAMPLE_COVERAGE_VALUE = 0x80AA,
        SAMPLE_COVERAGE_INVERT = 0x80AB,
        NUM_COMPRESSED_TEXTURE_FORMATS = 0x86A2,
        COMPRESSED_TEXTURE_FORMATS = 0x86A3,
        DONT_CARE = 0x1100,
        FASTEST = 0x1101,
        NICEST = 0x1102,
        GENERATE_MIPMAP_HINT = 0x8192,
        BYTE = 0x1400,
        UNSIGNED_BYTE = 0x1401,
        SHORT = 0x1402,
        UNSIGNED_SHORT = 0x1403,
        INT = 0x1404,
        UNSIGNED_INT = 0x1405,
        FLOAT = 0x1406,
        FIXED = 0x140C,
        DEPTH_COMPONENT = 0x1902,
        ALPHA = 0x1906,
        RGB = 0x1907,
        RGBA = 0x1908,
        LUMINANCE = 0x1909,
        LUMINANCE_ALPHA = 0x190A,
        UNSIGNED_SHORT_4_4_4_4 = 0x8033,
        UNSIGNED_SHORT_5_5_5_1 = 0x8034,
        UNSIGNED_SHORT_5_6_5 = 0x8363,
        FRAGMENT_SHADER = 0x8B30,
        VERTEX_SHADER = 0x8B31,
        MAX_VERTEX_ATTRIBS = 0x8869,
        MAX_VERTEX_UNIFORM_VECTORS = 0x8DFB,
        MAX_VARYING_VECTORS = 0x8DFC,
        MAX_COMBINED_TEXTURE_IMAGE_UNITS = 0x8B4D,
        MAX_VERTEX_TEXTURE_IMAGE_UNITS = 0x8B4C,
        MAX_TEXTURE_IMAGE_UNITS = 0x8872,
        MAX_FRAGMENT_UNIFORM_VECTORS = 0x8DFD,
        SHADER_TYPE = 0x8B4F,
        DELETE_STATUS = 0x8B80,
        LINK_STATUS = 0x8B82,
        VALIDATE_STATUS = 0x8B83,
        ATTACHED_SHADERS = 0x8B85,
        ACTIVE_UNIFORMS = 0x8B86,
        ACTIVE_UNIFORM_MAX_LENGTH = 0x8B87,
        ACTIVE_ATTRIBUTES = 0x8B89,
        ACTIVE_ATTRIBUTE_MAX_LENGTH = 0x8B8A,
        SHADING_LANGUAGE_VERSION = 0x8B8C,
        CURRENT_PROGRAM = 0x8B8D,
        NEVER = 0x0200,
        LESS = 0x0201,
        EQUAL = 0x0202,
        LEQUAL = 0x0203,
        GREATER = 0x0204,
        NOTEQUAL = 0x0205,
        GEQUAL = 0x0206,
        ALWAYS = 0x0207,
        KEEP = 0x1E00,
        REPLACE = 0x1E01,
        INCR = 0x1E02,
        DECR = 0x1E03,
        INVERT = 0x150A,
        INCR_WRAP = 0x8507,
        DECR_WRAP = 0x8508,
        VENDOR = 0x1F00,
        RENDERER = 0x1F01,
        VERSION = 0x1F02,
        EXTENSIONS = 0x1F03,
        NEAREST = 0x2600,
        LINEAR = 0x2601,
        NEAREST_MIPMAP_NEAREST = 0x2700,
        LINEAR_MIPMAP_NEAREST = 0x2701,
        NEAREST_MIPMAP_LINEAR = 0x2702,
        LINEAR_MIPMAP_LINEAR = 0x2703,
        TEXTURE_MAG_FILTER = 0x2800,
        TEXTURE_MIN_FILTER = 0x2801,
        TEXTURE_WRAP_S = 0x2802,
        TEXTURE_WRAP_T = 0x2803,
        TEXTURE = 0x1702,
        TEXTURE_CUBE_MAP = 0x8513,
        TEXTURE_BINDING_CUBE_MAP = 0x8514,
        TEXTURE_CUBE_MAP_POSITIVE_X = 0x8515,
        TEXTURE_CUBE_MAP_NEGATIVE_X = 0x8516,
        TEXTURE_CUBE_MAP_POSITIVE_Y = 0x8517,
        TEXTURE_CUBE_MAP_NEGATIVE_Y = 0x8518,
        TEXTURE_CUBE_MAP_POSITIVE_Z = 0x8519,
        TEXTURE_CUBE_MAP_NEGATIVE_Z = 0x851A,
        MAX_CUBE_MAP_TEXTURE_SIZE = 0x851C,
        TEXTURE0 = 0x84C0,
        TEXTURE1 = 0x84C1,
        TEXTURE2 = 0x84C2,
        TEXTURE3 = 0x84C3,
        TEXTURE4 = 0x84C4,
        TEXTURE5 = 0x84C5,
        TEXTURE6 = 0x84C6,
        TEXTURE7 = 0x84C7,
        TEXTURE8 = 0x84C8,
        TEXTURE9 = 0x84C9,
        TEXTURE10 = 0x84CA,
        TEXTURE11 = 0x84CB,
        TEXTURE12 = 0x84CC,
        TEXTURE13 = 0x84CD,
        TEXTURE14 = 0x84CE,
        TEXTURE15 = 0x84CF,
        TEXTURE16 = 0x84D0,
        TEXTURE17 = 0x84D1,
        TEXTURE18 = 0x84D2,
        TEXTURE19 = 0x84D3,
        TEXTURE20 = 0x84D4,
        TEXTURE21 = 0x84D5,
        TEXTURE22 = 0x84D6,
        TEXTURE23 = 0x84D7,
        TEXTURE24 = 0x84D8,
        TEXTURE25 = 0x84D9,
        TEXTURE26 = 0x84DA,
        TEXTURE27 = 0x84DB,
        TEXTURE28 = 0x84DC,
        TEXTURE29 = 0x84DD,
        TEXTURE30 = 0x84DE,
        TEXTURE31 = 0x84DF,
        ACTIVE_TEXTURE = 0x84E0,
        REPEAT = 0x2901,
        CLAMP_TO_EDGE = 0x812F,
        MIRRORED_REPEAT = 0x8370,
        FLOAT_VEC2 = 0x8B50,
        FLOAT_VEC3 = 0x8B51,
        FLOAT_VEC4 = 0x8B52,
        INT_VEC2 = 0x8B53,
        INT_VEC3 = 0x8B54,
        INT_VEC4 = 0x8B55,
        BOOL = 0x8B56,
        BOOL_VEC2 = 0x8B57,
        BOOL_VEC3 = 0x8B58,
        BOOL_VEC4 = 0x8B59,
        FLOAT_MAT2 = 0x8B5A,
        FLOAT_MAT3 = 0x8B5B,
        FLOAT_MAT4 = 0x8B5C,
        SAMPLER_2D = 0x8B5E,
        SAMPLER_CUBE = 0x8B60,
        VERTEX_ATTRIB_ARRAY_ENABLED = 0x8622,
        VERTEX_ATTRIB_ARRAY_SIZE = 0x8623,
        VERTEX_ATTRIB_ARRAY_STRIDE = 0x8624,
        VERTEX_ATTRIB_ARRAY_TYPE = 0x8625,
        VERTEX_ATTRIB_ARRAY_NORMALIZED = 0x886A,
        VERTEX_ATTRIB_ARRAY_POINTER = 0x8645,
        VERTEX_ATTRIB_ARRAY_BUFFER_BINDING = 0x889F,
        COMPILE_STATUS = 0x8B81,
        INFO_LOG_LENGTH = 0x8B84,
        SHADER_SOURCE_LENGTH = 0x8B88,
        SHADER_COMPILER = 0x8DFA,
        SHADER_BINARY_FORMATS = 0x8DF8,
        NUM_SHADER_BINARY_FORMATS = 0x8DF9,
        LOW_FLOAT = 0x8DF0,
        MEDIUM_FLOAT = 0x8DF1,
        HIGH_FLOAT = 0x8DF2,
        LOW_INT = 0x8DF3,
        MEDIUM_INT = 0x8DF4,
        HIGH_INT = 0x8DF5,
        FRAMEBUFFER = 0x8D40,
        RENDERBUFFER = 0x8D41,
        RGBA4 = 0x8056,
        RGB5_A1 = 0x8057,
        RGB565 = 0x8D62,
        DEPTH_COMPONENT16 = 0x81A5,
        STENCIL_INDEX = 0x1901,
        STENCIL_INDEX8 = 0x8D48,
        DEPTH_STENCIL = 0x84F9,
        RENDERBUFFER_WIDTH = 0x8D42,
        RENDERBUFFER_HEIGHT = 0x8D43,
        RENDERBUFFER_INTERNAL_FORMAT = 0x8D44,
        RENDERBUFFER_RED_SIZE = 0x8D50,
        RENDERBUFFER_GREEN_SIZE = 0x8D51,
        RENDERBUFFER_BLUE_SIZE = 0x8D52,
        RENDERBUFFER_ALPHA_SIZE = 0x8D53,
        RENDERBUFFER_DEPTH_SIZE = 0x8D54,
        RENDERBUFFER_STENCIL_SIZE = 0x8D55,
        FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE = 0x8CD0,
        FRAMEBUFFER_ATTACHMENT_OBJECT_NAME = 0x8CD1,
        FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL = 0x8CD2,
        FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE = 0x8CD3,
        COLOR_ATTACHMENT0 = 0x8CE0,
        DEPTH_ATTACHMENT = 0x8D00,
        STENCIL_ATTACHMENT = 0x8D20,
        DEPTH_STENCIL_ATTACHMENT = 0x821A,
        NONE = 0,
        FRAMEBUFFER_COMPLETE = 0x8CD5,
        FRAMEBUFFER_INCOMPLETE_ATTACHMENT = 0x8CD6,
        FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT = 0x8CD7,
        FRAMEBUFFER_INCOMPLETE_DIMENSIONS = 0x8CD9,
        FRAMEBUFFER_UNSUPPORTED = 0x8CDD,
        FRAMEBUFFER_BINDING = 0x8CA6,
        RENDERBUFFER_BINDING = 0x8CA7,
        MAX_RENDERBUFFER_SIZE = 0x84E8,
        INVALID_FRAMEBUFFER_OPERATION = 0x0506,

        // WebGL-specific enums
        UNPACK_FLIP_Y_WEBGL = 0x9240,
        UNPACK_PREMULTIPLY_ALPHA_WEBGL = 0x9241,
        CONTEXT_LOST_WEBGL = 0x9242,
        UNPACK_COLORSPACE_CONVERSION_WEBGL = 0x9243,
        BROWSER_DEFAULT_WEBGL = 0x9244
    };

    // Context creation attributes.
    struct Attributes {
        Attributes()
            : alpha(true)
            , depth(true)
            , stencil(false)
            , antialias(true)
            , premultipliedAlpha(true)
            , canRecoverFromContextLoss(true)
            , preserveDrawingBuffer(false)
            , noExtensions(false)
            , shareResources(true)
        {
        }

        bool alpha;
        bool depth;
        bool stencil;
        bool antialias;
        bool premultipliedAlpha;
        bool canRecoverFromContextLoss;
        bool preserveDrawingBuffer;
        bool noExtensions;
        bool shareResources;
    };

    enum RenderStyle {
        RenderOffscreen,
        RenderDirectlyToHostWindow
    };

    class ContextLostCallback {
    public:
        virtual void onContextLost() = 0;
        virtual ~ContextLostCallback() {}
    };

    void setContextLostCallback(PassOwnPtr<ContextLostCallback>);

    static PassRefPtr<GraphicsContext3D> create(Attributes, HostWindow*, RenderStyle = RenderOffscreen);
    ~GraphicsContext3D();

#if PLATFORM(MAC)
    PlatformGraphicsContext3D platformGraphicsContext3D() const { return m_contextObj; }
    Platform3DObject platformTexture() const { return m_compositorTexture; }
    CALayer* platformLayer() const { return reinterpret_cast<CALayer*>(m_webGLLayer.get()); }
#elif PLATFORM(CHROMIUM)
    PlatformGraphicsContext3D platformGraphicsContext3D() const;
    Platform3DObject platformTexture() const;
#if USE(SKIA)
    GrContext* grContext();
#endif
#if USE(ACCELERATED_COMPOSITING)
    PlatformLayer* platformLayer() const;
#endif
#elif PLATFORM(QT)
    PlatformGraphicsContext3D platformGraphicsContext3D();
    Platform3DObject platformTexture() const;
#if USE(ACCELERATED_COMPOSITING)
    PlatformLayer* platformLayer() const;
#endif
#elif PLATFORM(GTK)
    PlatformGraphicsContext3D platformGraphicsContext3D();
    Platform3DObject platformTexture() const { return m_texture; }
#if USE(ACCELERATED_COMPOSITING)
    PlatformLayer* platformLayer() const;
#endif
#elif PLATFORM(EFL)
    PlatformGraphicsContext3D platformGraphicsContext3D() const;
#if USE(ACCELERATED_COMPOSITING)
    PlatformLayer* platformLayer() const;
#endif
#else
    PlatformGraphicsContext3D platformGraphicsContext3D() const { return NullPlatformGraphicsContext3D; }
    Platform3DObject platformTexture() const { return NullPlatform3DObject; }
#if USE(ACCELERATED_COMPOSITING)
    PlatformLayer* platformLayer() const { return 0; }
#endif
#endif
    bool makeContextCurrent();

#if PLATFORM(MAC) || PLATFORM(CHROMIUM) || PLATFORM(GTK) || PLATFORM(QT)
    // With multisampling on, blit from multisampleFBO to regular FBO.
    void prepareTexture();
#endif

    // Helper to texImage2D with pixel==0 case: pixels are initialized to 0.
    // Return true if no GL error is synthesized.
    // By default, alignment is 4, the OpenGL default setting.
    bool texImage2DResourceSafe(GC3Denum target, GC3Dint level, GC3Denum internalformat, GC3Dsizei width, GC3Dsizei height, GC3Dint border, GC3Denum format, GC3Denum type, GC3Dint alignment = 4);

    bool isGLES2Compliant() const;

    //----------------------------------------------------------------------
    // Helpers for texture uploading and pixel readback.
    //

    // Computes the components per pixel and bytes per component
    // for the given format and type combination. Returns false if
    // either was an invalid enum.
    static bool computeFormatAndTypeParameters(GC3Denum format,
                                               GC3Denum type,
                                               unsigned int* componentsPerPixel,
                                               unsigned int* bytesPerComponent);

    // Computes the image size in bytes. If paddingInBytes is not null, padding
    // is also calculated in return. Returns NO_ERROR if succeed, otherwise
    // return the suggested GL error indicating the cause of the failure:
    //   INVALID_VALUE if width/height is negative or overflow happens.
    //   INVALID_ENUM if format/type is illegal.
    GC3Denum computeImageSizeInBytes(GC3Denum format,
                                     GC3Denum type,
                                     GC3Dsizei width,
                                     GC3Dsizei height,
                                     GC3Dint alignment,
                                     unsigned int* imageSizeInBytes,
                                     unsigned int* paddingInBytes);

    // Extracts the contents of the given Image into the passed Vector,
    // packing the pixel data according to the given format and type,
    // and obeying the flipY, premultiplyAlpha, and ignoreGammaAndColorProfile
    // flags. Returns true upon success.
    bool extractImageData(Image* image,
                          GC3Denum format,
                          GC3Denum type,
                          bool flipY,
                          bool premultiplyAlpha,
                          bool ignoreGammaAndColorProfile,
                          Vector<uint8_t>& data);

    // Extracts the contents of the given ImageData into the passed Vector,
    // packing the pixel data according to the given format and type,
    // and obeying the flipY and premultiplyAlpha flags. Returns true
    // upon success.
    bool extractImageData(ImageData*,
                          GC3Denum format,
                          GC3Denum type,
                          bool flipY,
                          bool premultiplyAlpha,
                          Vector<uint8_t>& data);

    // Helper function which extracts the user-supplied texture
    // data, applying the flipY and premultiplyAlpha parameters.
    // If the data is not tightly packed according to the passed
    // unpackAlignment, the output data will be tightly packed.
    // Returns true if successful, false if any error occurred.
    bool extractTextureData(unsigned int width, unsigned int height,
                            GC3Denum format, GC3Denum type,
                            unsigned int unpackAlignment,
                            bool flipY, bool premultiplyAlpha,
                            const void* pixels,
                            Vector<uint8_t>& data);

    // Flips the given image data vertically, in-place.
    void flipVertically(void* imageData,
                        unsigned int width,
                        unsigned int height,
                        unsigned int bytesPerPixel,
                        unsigned int unpackAlignment);

    // Attempt to enumerate all possible native image formats to
    // reduce the amount of temporary allocations during texture
    // uploading. This enum must be public because it is accessed
    // by non-member functions.
    enum SourceDataFormat {
        SourceFormatRGBA8 = 0,
        SourceFormatRGBA16Little,
        SourceFormatRGBA16Big,
        SourceFormatRGBA32F,
        SourceFormatRGB8,
        SourceFormatRGB16Little,
        SourceFormatRGB16Big,
        SourceFormatRGB32F,
        SourceFormatBGR8,
        SourceFormatBGRA8,
        SourceFormatBGRA16Little,
        SourceFormatBGRA16Big,
        SourceFormatARGB8,
        SourceFormatARGB16Little,
        SourceFormatARGB16Big,
        SourceFormatABGR8,
        SourceFormatRGBA5551,
        SourceFormatRGBA4444,
        SourceFormatRGB565,
        SourceFormatR8,
        SourceFormatR16Little,
        SourceFormatR16Big,
        SourceFormatR32F,
        SourceFormatRA8,
        SourceFormatRA16Little,
        SourceFormatRA16Big,
        SourceFormatRA32F,
        SourceFormatAR8,
        SourceFormatAR16Little,
        SourceFormatAR16Big,
        SourceFormatA8,
        SourceFormatA16Little,
        SourceFormatA16Big,
        SourceFormatA32F,
        SourceFormatNumFormats
    };

    //----------------------------------------------------------------------
    // Entry points for WebGL.
    //

    void activeTexture(GC3Denum texture);
    void attachShader(Platform3DObject program, Platform3DObject shader);
    void bindAttribLocation(Platform3DObject, GC3Duint index, const String& name);
    void bindBuffer(GC3Denum target, Platform3DObject);
    void bindFramebuffer(GC3Denum target, Platform3DObject);
    void bindRenderbuffer(GC3Denum target, Platform3DObject);
    void bindTexture(GC3Denum target, Platform3DObject);
    void blendColor(GC3Dclampf red, GC3Dclampf green, GC3Dclampf blue, GC3Dclampf alpha);
    void blendEquation(GC3Denum mode);
    void blendEquationSeparate(GC3Denum modeRGB, GC3Denum modeAlpha);
    void blendFunc(GC3Denum sfactor, GC3Denum dfactor);
    void blendFuncSeparate(GC3Denum srcRGB, GC3Denum dstRGB, GC3Denum srcAlpha, GC3Denum dstAlpha);

    void bufferData(GC3Denum target, GC3Dsizeiptr size, GC3Denum usage);
    void bufferData(GC3Denum target, GC3Dsizeiptr size, const void* data, GC3Denum usage);
    void bufferSubData(GC3Denum target, GC3Dintptr offset, GC3Dsizeiptr size, const void* data);

    GC3Denum checkFramebufferStatus(GC3Denum target);
    void clear(GC3Dbitfield mask);
    void clearColor(GC3Dclampf red, GC3Dclampf green, GC3Dclampf blue, GC3Dclampf alpha);
    void clearDepth(GC3Dclampf depth);
    void clearStencil(GC3Dint s);
    void colorMask(GC3Dboolean red, GC3Dboolean green, GC3Dboolean blue, GC3Dboolean alpha);
    void compileShader(Platform3DObject);

    void compressedTexImage2D(GC3Denum target, GC3Dint level, GC3Denum internalformat, GC3Dsizei width, GC3Dsizei height, GC3Dint border, GC3Dsizei imageSize, const void* data);
    void compressedTexSubImage2D(GC3Denum target, GC3Dint level, GC3Dint xoffset, GC3Dint yoffset, GC3Dsizei width, GC3Dsizei height, GC3Denum format, GC3Dsizei imageSize, const void* data);
    void copyTexImage2D(GC3Denum target, GC3Dint level, GC3Denum internalformat, GC3Dint x, GC3Dint y, GC3Dsizei width, GC3Dsizei height, GC3Dint border);
    void copyTexSubImage2D(GC3Denum target, GC3Dint level, GC3Dint xoffset, GC3Dint yoffset, GC3Dint x, GC3Dint y, GC3Dsizei width, GC3Dsizei height);
    void cullFace(GC3Denum mode);
    void depthFunc(GC3Denum func);
    void depthMask(GC3Dboolean flag);
    void depthRange(GC3Dclampf zNear, GC3Dclampf zFar);
    void detachShader(Platform3DObject, Platform3DObject);
    void disable(GC3Denum cap);
    void disableVertexAttribArray(GC3Duint index);
    void drawArrays(GC3Denum mode, GC3Dint first, GC3Dsizei count);
    void drawElements(GC3Denum mode, GC3Dsizei count, GC3Denum type, GC3Dintptr offset);

    void enable(GC3Denum cap);
    void enableVertexAttribArray(GC3Duint index);
    void finish();
    void flush();
    void framebufferRenderbuffer(GC3Denum target, GC3Denum attachment, GC3Denum renderbuffertarget, Platform3DObject);
    void framebufferTexture2D(GC3Denum target, GC3Denum attachment, GC3Denum textarget, Platform3DObject, GC3Dint level);
    void frontFace(GC3Denum mode);
    void generateMipmap(GC3Denum target);

    bool getActiveAttrib(Platform3DObject program, GC3Duint index, ActiveInfo&);
    bool getActiveUniform(Platform3DObject program, GC3Duint index, ActiveInfo&);
    void getAttachedShaders(Platform3DObject program, GC3Dsizei maxCount, GC3Dsizei* count, Platform3DObject* shaders);
    GC3Dint getAttribLocation(Platform3DObject, const String& name);
    void getBooleanv(GC3Denum pname, GC3Dboolean* value);
    void getBufferParameteriv(GC3Denum target, GC3Denum pname, GC3Dint* value);
    Attributes getContextAttributes();
    GC3Denum getError();
    void getFloatv(GC3Denum pname, GC3Dfloat* value);
    void getFramebufferAttachmentParameteriv(GC3Denum target, GC3Denum attachment, GC3Denum pname, GC3Dint* value);
    void getIntegerv(GC3Denum pname, GC3Dint* value);
    void getProgramiv(Platform3DObject program, GC3Denum pname, GC3Dint* value);
    String getProgramInfoLog(Platform3DObject);
    void getRenderbufferParameteriv(GC3Denum target, GC3Denum pname, GC3Dint* value);
    void getShaderiv(Platform3DObject, GC3Denum pname, GC3Dint* value);
    String getShaderInfoLog(Platform3DObject);

    // TBD
    // void glGetShaderPrecisionFormat (GC3Denum shadertype, GC3Denum precisiontype, GC3Dint* range, GC3Dint* precision);

    String getShaderSource(Platform3DObject);
    String getString(GC3Denum name);
    void getTexParameterfv(GC3Denum target, GC3Denum pname, GC3Dfloat* value);
    void getTexParameteriv(GC3Denum target, GC3Denum pname, GC3Dint* value);
    void getUniformfv(Platform3DObject program, GC3Dint location, GC3Dfloat* value);
    void getUniformiv(Platform3DObject program, GC3Dint location, GC3Dint* value);
    GC3Dint getUniformLocation(Platform3DObject, const String& name);
    void getVertexAttribfv(GC3Duint index, GC3Denum pname, GC3Dfloat* value);
    void getVertexAttribiv(GC3Duint index, GC3Denum pname, GC3Dint* value);
    GC3Dsizeiptr getVertexAttribOffset(GC3Duint index, GC3Denum pname);

    void hint(GC3Denum target, GC3Denum mode);
    GC3Dboolean isBuffer(Platform3DObject);
    GC3Dboolean isEnabled(GC3Denum cap);
    GC3Dboolean isFramebuffer(Platform3DObject);
    GC3Dboolean isProgram(Platform3DObject);
    GC3Dboolean isRenderbuffer(Platform3DObject);
    GC3Dboolean isShader(Platform3DObject);
    GC3Dboolean isTexture(Platform3DObject);
    void lineWidth(GC3Dfloat);
    void linkProgram(Platform3DObject);
    void pixelStorei(GC3Denum pname, GC3Dint param);
    void polygonOffset(GC3Dfloat factor, GC3Dfloat units);

    void readPixels(GC3Dint x, GC3Dint y, GC3Dsizei width, GC3Dsizei height, GC3Denum format, GC3Denum type, void* data);

    void releaseShaderCompiler();

    void renderbufferStorage(GC3Denum target, GC3Denum internalformat, GC3Dsizei width, GC3Dsizei height);
    void sampleCoverage(GC3Dclampf value, GC3Dboolean invert);
    void scissor(GC3Dint x, GC3Dint y, GC3Dsizei width, GC3Dsizei height);
    void shaderSource(Platform3DObject, const String& string);
    void stencilFunc(GC3Denum func, GC3Dint ref, GC3Duint mask);
    void stencilFuncSeparate(GC3Denum face, GC3Denum func, GC3Dint ref, GC3Duint mask);
    void stencilMask(GC3Duint mask);
    void stencilMaskSeparate(GC3Denum face, GC3Duint mask);
    void stencilOp(GC3Denum fail, GC3Denum zfail, GC3Denum zpass);
    void stencilOpSeparate(GC3Denum face, GC3Denum fail, GC3Denum zfail, GC3Denum zpass);

    bool texImage2D(GC3Denum target, GC3Dint level, GC3Denum internalformat, GC3Dsizei width, GC3Dsizei height, GC3Dint border, GC3Denum format, GC3Denum type, const void* pixels);
    void texParameterf(GC3Denum target, GC3Denum pname, GC3Dfloat param);
    void texParameteri(GC3Denum target, GC3Denum pname, GC3Dint param);
    void texSubImage2D(GC3Denum target, GC3Dint level, GC3Dint xoffset, GC3Dint yoffset, GC3Dsizei width, GC3Dsizei height, GC3Denum format, GC3Denum type, const void* pixels);

    // FIXME: change the argument orders to match OpenGL's.
    void uniform1f(GC3Dint location, GC3Dfloat x);
    void uniform1fv(GC3Dint location, GC3Dfloat* v, GC3Dsizei size);
    void uniform1i(GC3Dint location, GC3Dint x);
    void uniform1iv(GC3Dint location, GC3Dint* v, GC3Dsizei size);
    void uniform2f(GC3Dint location, GC3Dfloat x, float y);
    void uniform2fv(GC3Dint location, GC3Dfloat* v, GC3Dsizei size);
    void uniform2i(GC3Dint location, GC3Dint x, GC3Dint y);
    void uniform2iv(GC3Dint location, GC3Dint* v, GC3Dsizei size);
    void uniform3f(GC3Dint location, GC3Dfloat x, GC3Dfloat y, GC3Dfloat z);
    void uniform3fv(GC3Dint location, GC3Dfloat* v, GC3Dsizei size);
    void uniform3i(GC3Dint location, GC3Dint x, GC3Dint y, GC3Dint z);
    void uniform3iv(GC3Dint location, GC3Dint* v, GC3Dsizei size);
    void uniform4f(GC3Dint location, GC3Dfloat x, GC3Dfloat y, GC3Dfloat z, GC3Dfloat w);
    void uniform4fv(GC3Dint location, GC3Dfloat* v, GC3Dsizei size);
    void uniform4i(GC3Dint location, GC3Dint x, GC3Dint y, GC3Dint z, GC3Dint w);
    void uniform4iv(GC3Dint location, GC3Dint* v, GC3Dsizei size);
    void uniformMatrix2fv(GC3Dint location, GC3Dboolean transpose, GC3Dfloat* value, GC3Dsizei size);
    void uniformMatrix3fv(GC3Dint location, GC3Dboolean transpose, GC3Dfloat* value, GC3Dsizei size);
    void uniformMatrix4fv(GC3Dint location, GC3Dboolean transpose, GC3Dfloat* value, GC3Dsizei size);

    void useProgram(Platform3DObject);
    void validateProgram(Platform3DObject);

    void vertexAttrib1f(GC3Duint index, GC3Dfloat x);
    void vertexAttrib1fv(GC3Duint index, GC3Dfloat* values);
    void vertexAttrib2f(GC3Duint index, GC3Dfloat x, GC3Dfloat y);
    void vertexAttrib2fv(GC3Duint index, GC3Dfloat* values);
    void vertexAttrib3f(GC3Duint index, GC3Dfloat x, GC3Dfloat y, GC3Dfloat z);
    void vertexAttrib3fv(GC3Duint index, GC3Dfloat* values);
    void vertexAttrib4f(GC3Duint index, GC3Dfloat x, GC3Dfloat y, GC3Dfloat z, GC3Dfloat w);
    void vertexAttrib4fv(GC3Duint index, GC3Dfloat* values);
    void vertexAttribPointer(GC3Duint index, GC3Dint size, GC3Denum type, GC3Dboolean normalized,
                             GC3Dsizei stride, GC3Dintptr offset);

    void viewport(GC3Dint x, GC3Dint y, GC3Dsizei width, GC3Dsizei height);

    void reshape(int width, int height);

#if USE(CG)
    static void paintToCanvas(const unsigned char* imagePixels, int imageWidth, int imageHeight,
                              int canvasWidth, int canvasHeight, CGContextRef);
#elif PLATFORM(GTK)
    void paintToCanvas(const unsigned char* imagePixels, int imageWidth, int imageHeight,
                       int canvasWidth, int canvasHeight, PlatformContextCairo* context);
#endif

    void markContextChanged();
    void markLayerComposited();
    bool layerComposited() const;

    void paintRenderingResultsToCanvas(CanvasRenderingContext*, DrawingBuffer*);
    PassRefPtr<ImageData> paintRenderingResultsToImageData(DrawingBuffer*);
    bool paintCompositedResultsToCanvas(CanvasRenderingContext*);

#if PLATFORM(QT)
    bool paintsIntoCanvasBuffer() const { return true; }
#elif PLATFORM(CHROMIUM)
    bool paintsIntoCanvasBuffer() const;
#elif PLATFORM(GTK)
    bool paintsIntoCanvasBuffer() const { return true; }
#else
    bool paintsIntoCanvasBuffer() const { return false; }
#endif

    // Support for buffer creation and deletion
    Platform3DObject createBuffer();
    Platform3DObject createFramebuffer();
    Platform3DObject createProgram();
    Platform3DObject createRenderbuffer();
    Platform3DObject createShader(GC3Denum);
    Platform3DObject createTexture();

    void deleteBuffer(Platform3DObject);
    void deleteFramebuffer(Platform3DObject);
    void deleteProgram(Platform3DObject);
    void deleteRenderbuffer(Platform3DObject);
    void deleteShader(Platform3DObject);
    void deleteTexture(Platform3DObject);

    // Synthesizes an OpenGL error which will be returned from a
    // later call to getError. This is used to emulate OpenGL ES
    // 2.0 behavior on the desktop and to enforce additional error
    // checking mandated by WebGL.
    //
    // Per the behavior of glGetError, this stores at most one
    // instance of any given error, and returns them from calls to
    // getError in the order they were added.
    void synthesizeGLError(GC3Denum error);

    // Support for extensions. Returns a non-null object, though not
    // all methods it contains may necessarily be supported on the
    // current hardware. Must call Extensions3D::supports() to
    // determine this.
    Extensions3D* getExtensions();

    IntSize getInternalFramebufferSize() const;

  private:
    GraphicsContext3D(Attributes attrs, HostWindow* hostWindow, bool renderDirectlyToHostWindow);

    // Each platform must provide an implementation of this method.
    //
    // Gets the data for the given Image into outputVector in the
    // format specified by the (OpenGL-style) format and type
    // arguments. Despite the fact that the outputVector contains
    // uint8_t, if the format and type specify packed pixels, then
    // it will essentially contain uint16_t after the extraction
    // process.
    //
    // If premultiplyAlpha is true, the alpha channel, if any,
    // will be multiplied into the color channels during the
    // extraction process. This premultiplication occurs before
    // any packing of pixel data.
    //
    // If ignoreGammaAndColorProfile is true, gamma correction and ICC
    // profile won't be applied.
    //
    // No vertical flip of the image data is performed by this
    // method.
    bool getImageData(Image* image,
                      GC3Denum format,
                      GC3Denum type,
                      bool premultiplyAlpha,
                      bool ignoreGammaAndColorProfile,
                      Vector<uint8_t>& outputVector);

    // Possible alpha operations that may need to occur during
    // pixel packing. FIXME: kAlphaDoUnmultiply is lossy and must
    // be removed.
    enum AlphaOp {
        AlphaDoNothing = 0,
        AlphaDoPremultiply = 1,
        AlphaDoUnmultiply = 2
    };

    // Helper for getImageData which implements packing of pixel
    // data into the specified OpenGL destination format and type.
    // A sourceUnpackAlignment of zero indicates that the source
    // data is tightly packed. Non-zero values may take a slow path.
    // Destination data will have no gaps between rows.
    bool packPixels(const uint8_t* sourceData,
                    SourceDataFormat sourceDataFormat,
                    unsigned int width,
                    unsigned int height,
                    unsigned int sourceUnpackAlignment,
                    unsigned int destinationFormat,
                    unsigned int destinationType,
                    AlphaOp alphaOp,
                    void* destinationData);

#if PLATFORM(MAC) || PLATFORM(GTK) || PLATFORM(QT)
    // Take into account the user's requested context creation attributes,
    // in particular stencil and antialias, and determine which could or
    // could not be honored based on the capabilities of the OpenGL
    // implementation.
    void validateAttributes();

    // Read rendering results into a pixel array with the same format as the
    // backbuffer.
    void readRenderingResults(unsigned char* pixels, int pixelsSize);
#endif

    int m_currentWidth, m_currentHeight;
    bool isResourceSafe();

#if PLATFORM(MAC)
    CGLContextObj m_contextObj;
    RetainPtr<WebGLLayer> m_webGLLayer;
#endif

#if PLATFORM(MAC) || PLATFORM(GTK) || PLATFORM(QT)
    typedef struct {
        String source;
        String log;
        bool isValid;
    } ShaderSourceEntry;
    HashMap<Platform3DObject, ShaderSourceEntry> m_shaderSourceMap;

    ANGLEWebKitBridge m_compiler;
#if PLATFORM(QT) && defined(QT_OPENGL_ES_2)
    friend class Extensions3DQt;
    OwnPtr<Extensions3DQt> m_extensions;
#else
    friend class Extensions3DOpenGL;
    OwnPtr<Extensions3DOpenGL> m_extensions;
#endif

    Attributes m_attrs;
    Vector<Vector<float> > m_vertexArray;

    GC3Duint m_texture, m_compositorTexture;
    GC3Duint m_fbo;
#if PLATFORM(QT) && defined(QT_OPENGL_ES_2)
    GC3Duint m_depthBuffer;
    GC3Duint m_stencilBuffer;
#else
    GC3Duint m_depthStencilBuffer;
#endif
    bool m_layerComposited;
    GC3Duint m_internalColorFormat;

    // For tracking which FBO/texture is bound
    GC3Duint m_boundFBO;
    GC3Denum m_activeTexture;
    GC3Duint m_boundTexture0;

    // For multisampling
    GC3Duint m_multisampleFBO;
    GC3Duint m_multisampleDepthStencilBuffer;
    GC3Duint m_multisampleColorBuffer;

    // Errors raised by synthesizeGLError().
    ListHashSet<GC3Denum> m_syntheticErrors;
#endif

    friend class GraphicsContext3DPrivate;
    OwnPtr<GraphicsContext3DPrivate> m_private;
};

} // namespace WebCore

#endif // GraphicsContext3D_h
