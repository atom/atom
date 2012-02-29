/* Copyright (c) 2006-2009 The Chromium Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifndef _NP_EXTENSIONS_H_
#define _NP_EXTENSIONS_H_

// Use the shorter include path here so that this file can be used in non-
// Chromium projects, such as the Native Client SDK.
#include "npapi.h"

#include <stddef.h>         // For size_t

/*
 * A fake "enum" value for getting browser-implemented Pepper extensions.
 * The variable returns a pointer to an NPNExtensions structure. */
#define NPNVPepperExtensions ((NPNVariable) 4000)

/*
 * A fake "enum" value for getting plugin-implemented Pepper extensions.
 * The variable returns a pointer to an NPPExtensions structure. */
#define NPPVPepperExtensions ((NPPVariable) 4001)

typedef void NPDeviceConfig;
typedef void NPDeviceContext;
typedef void NPUserData;

/* unique id for each device interface */
typedef int32_t NPDeviceID;

/* Events -------------------------------------------------------------------*/

typedef enum {
  NPMouseButton_None    = -1,
  NPMouseButton_Left    = 0,
  NPMouseButton_Middle  = 1,
  NPMouseButton_Right   = 2
} NPMouseButtons;

typedef enum {
  NPEventType_Undefined   = -1,
  NPEventType_MouseDown   = 0,
  NPEventType_MouseUp     = 1,
  NPEventType_MouseMove   = 2,
  NPEventType_MouseEnter  = 3,
  NPEventType_MouseLeave  = 4,
  NPEventType_MouseWheel  = 5,
  NPEventType_RawKeyDown  = 6,
  NPEventType_KeyDown     = 7,
  NPEventType_KeyUp       = 8,
  NPEventType_Char        = 9,
  NPEventType_Minimize    = 10,
  NPEventType_Focus       = 11,
  NPEventType_Device      = 12
} NPEventTypes;

typedef enum {
  NPEventModifier_ShiftKey         = 1 << 0,
  NPEventModifier_ControlKey       = 1 << 1,
  NPEventModifier_AltKey           = 1 << 2,
  NPEventModifier_MetaKey          = 1 << 3,
  NPEventModifier_IsKeyPad         = 1 << 4,
  NPEventModifier_IsAutoRepeat     = 1 << 5,
  NPEventModifier_LeftButtonDown   = 1 << 6,
  NPEventModifier_MiddleButtonDown = 1 << 7,
  NPEventModifier_RightButtonDown  = 1 << 8
} NPEventModifiers;

typedef struct _NPKeyEvent
{
  uint32_t modifier;
  uint32_t normalizedKeyCode;
} NPKeyEvent;

typedef struct _NPCharacterEvent
{
  uint32_t modifier;
  uint16_t text[4];
  uint16_t unmodifiedText[4];
} NPCharacterEvent;

typedef struct _NPMouseEvent
{
  uint32_t modifier;
  int32_t button;
  int32_t x;
  int32_t y;
  int32_t clickCount;
} NPMouseEvent;

typedef struct _NPMouseWheelEvent
{
  uint32_t modifier;
  float deltaX;
  float deltaY;
  float wheelTicksX;
  float wheelTicksY;
  uint32_t scrollByPage;
} NPMouseWheelEvent;

typedef struct _NPDeviceEvent {
  uint32_t device_uid;
  uint32_t subtype;
  /* uint8_t generic[0]; */
} NPDeviceEvent;

typedef struct _NPMinimizeEvent {
  int32_t value;
} NPMinimizeEvent;

typedef struct _NPFocusEvent {
  int32_t value;
} NPFocusEvent;

typedef struct _NPPepperEvent
{
  uint32_t size;
  int32_t type;
  double timeStampSeconds;
  union {
    NPKeyEvent key;
    NPCharacterEvent character;
    NPMouseEvent mouse;
    NPMouseWheelEvent wheel;
    NPMinimizeEvent minimize;
    NPFocusEvent focus;
    NPDeviceEvent device;
  } u;
} NPPepperEvent;

/* 2D -----------------------------------------------------------------------*/

#define NPPepper2DDevice 1

typedef struct _NPDeviceContext2DConfig {
} NPDeviceContext2DConfig;

typedef struct _NPDeviceContext2D
{
  /* Internal value used by the browser to identify this device. */
  void* reserved;

  /* A pointer to the pixel data. This data is 8-bit values in BGRA order in
   * memory. Each row will start |stride| bytes after the previous one.
   *
   * THIS DATA USES PREMULTIPLIED ALPHA. This means that each color channel has
   * been multiplied with the corresponding alpha, which makes compositing
   * easier. If any color channels have a value greater than the alpha value,
   * you'll likely get crazy colors and weird artifacts. */
  void* region;

  /* Length of each row of pixels in bytes. This may be larger than width * 4
   * if there is padding at the end of each row to help with alignment. */
  int32_t stride;

  /* The dirty region that the plugin has painted into the buffer. This
   * will be initialized to the size of the plugin image in
   * initializeContextPtr. The plugin can change the values to only
   * update portions of the image. */
  struct {
    int32_t left;
    int32_t top;
    int32_t right;
    int32_t bottom;
  } dirty;
} NPDeviceContext2D;

typedef struct _NPDeviceBuffer {
  void* ptr;
  size_t size;
} NPDeviceBuffer;

/* completion callback for flush device */
typedef void (*NPDeviceFlushContextCallbackPtr)(
    NPP instance,
    NPDeviceContext* context,
    NPError err,
    NPUserData* userData);

/* query single capabilities of device */
typedef NPError (
    *NPDeviceQueryCapabilityPtr)(NPP instance,
    int32_t capability,
    int32_t *value);
/* query config (configuration == a set of capabilities) */
typedef NPError (
    *NPDeviceQueryConfigPtr)(NPP instance,
    const NPDeviceConfig* request,
    NPDeviceConfig* obtain);
/* device initialization */
typedef NPError (*NPDeviceInitializeContextPtr)(
    NPP instance,
    const NPDeviceConfig* config,
    NPDeviceContext* context);
/* peek at device state */
typedef NPError (*NPDeviceGetStateContextPtr) (
    NPP instance,
    NPDeviceContext* context,
    int32_t state,
    intptr_t* value);
/* poke device state */
typedef NPError (*NPDeviceSetStateContextPtr) (
    NPP instance,
    NPDeviceContext* context,
    int32_t state,
    intptr_t value);
/* flush context, if callback, userData are NULL */
/* this becomes a blocking call */
typedef NPError (*NPDeviceFlushContextPtr)(
    NPP instance,
    NPDeviceContext* context,
    NPDeviceFlushContextCallbackPtr callback,
    void* userData);
/* destroy device context.  Application responsible for */
/* freeing context, if applicable */
typedef NPError (*NPDeviceDestroyContextPtr)(
    NPP instance,
    NPDeviceContext* context);
/* Create a buffer associated with a particular context. The usage of the */
/* buffer is device specific. The lifetime of the buffer is scoped with the */
/* lifetime of the context. */
typedef NPError (*NPDeviceCreateBufferPtr)(
    NPP instance,
    NPDeviceContext* context,
    size_t size,
    int32_t* id);
/* Destroy a buffer associated with a particular context. */
typedef NPError (*NPDeviceDestroyBufferPtr)(
    NPP instance,
    NPDeviceContext* context,
    int32_t id);
/* Map a buffer id to its address. */
typedef NPError (*NPDeviceMapBufferPtr)(
    NPP instance,
    NPDeviceContext* context,
    int32_t id,
    NPDeviceBuffer* buffer);


/* forward decl typdef structs */
typedef struct NPDevice NPDevice;
typedef struct NPNExtensions NPNExtensions;

// DEPRECATED: this typedef is just for the NaCl code until they switch to NPNExtensions.
// PLEASE REMOVE THIS WHEN THE NACL CODE IS UPDATED.
typedef struct NPNExtensions NPExtensions;


/* New experimental device API. */

/* Mode for calls to NPDeviceSynchronizeContext. */
typedef enum {
  /* Get or set locally cached state without synchronizing or communicating   */
  /* with the service process (or thread).                                    */
  NPDeviceSynchronizationMode_Cached,

  /* Exchanges state with service process (or thread). Does not wait for any  */
  /* progress before returning.                                               */
  NPDeviceSynchronizationMode_Immediate,

  /* Exchanges state with service process (or thread). Blocks caller until    */
  /* further progress can be made.                                            */
  NPDeviceSynchronizationMode_Flush
} NPDeviceSynchronizationMode;

/* Get the number of configs supported by a given device. */
typedef NPError (*NPDeviceGetNumConfigsPtr)(NPP instance,
                                            int32_t* numConfigs);

/* Get attribute values from a config. NPDeviceGetConfigs might return        */
/* multiple configs. This function can be used to examine them to             */
/* find the most suitable. For example, NPDeviceGetConfigs might return one   */
/* config with antialiasing enabled and one without. This can be determined   */
/* using this function.                                                       */
/* Inputs:                                                                    */
/*  config: The config index to extract the attributes from.                  */
/*  attribList: Array of input config attribute / value pairs                 */
/*              terminated with NPAttrib_End.                                 */
/* Outputs:                                                                   */
/*  attribList: The values paired up with each attribute are filled in        */
/*              on return.                                                    */
typedef NPError (*NPDeviceGetConfigAttribsPtr)(NPP instance,
                                               int32_t config,
                                               int32_t* attribList);

/* Create a device context based on a particular device configuration and a   */
/* list config input attributes.                                              */
/* Inputs:                                                                    */
/*  config: The device configuration to use.                                  */
/*  attribList: NULL or an array of context specific attribute / value        */
/*              pairs terminated with NPAttrib_End.                           */
/* Outputs:                                                                   */
/*  context: The created context.                                             */
typedef NPError (*NPDeviceCreateContextPtr)(NPP instance,
                                            int32_t config,
                                            const int32_t* attribList,
                                            NPDeviceContext** context);

/* Destroy a context.                                                         */
/* Inputs:                                                                    */
/*  context: The context to destroy.                                          */
/*typedef NPError (*NPDestroyContext)(NPP instance,                           */
/*                                    NPDeviceContext* context);              */

/* This type should be cast to the type associated with the particular        */
/* callback type */
typedef void (*NPDeviceGenericCallbackPtr)(void);

/* Register a callback with a context. Callbacks are never invoked after the  */
/* associated context has been destroyed. The semantics of the particular     */
/* callback type determine which thread the callback is invoked on. It might  */
/* be the plugin thread, the thread RegisterCallback is invoked on or a       */
/* special thread created for servicing callbacks, such as an audio thread    */
/* Inputs:                                                                    */
/*  callbackType: The device specific callback type                           */
/*  callback: The callback to invoke. The signature varies by type. Use       */
/*            NULL to unregister the callback for a particular type.          */
/*  callbackData: A value that is passed to the callback function. Other      */
/*                callback arguments vary by type.                            */
typedef NPError (*NPDeviceRegisterCallbackPtr)(
    NPP instance,
    NPDeviceContext* context,
    int32_t callbackType,
    NPDeviceGenericCallbackPtr callback,
    void* callbackData);

/* Callback for NPDeviceSynchronizeContext.                                   */
/* Inputs:                                                                    */
/*  instance: The associated plugin instance.                                 */
/*  context: The context that was flushed.                                    */
/*  error: Indicates success of flush operation.                              */
/*  data: The completion callback data that was passed to                     */
/*        NPDeviceSynchronizeContext.                                         */
typedef void (*NPDeviceSynchronizeContextCallbackPtr)(
    NPP instance,
    NPDeviceContext* context,
    NPError error,
    void* data);

/* Synchronize the state of a device context. Takes lists of input and output */
/* attributes. Generally, the input attributes are copied into the context    */
/* and the output attributes are filled in the state of the context either    */
/* after (before) the synchronization depending on whether it is synchronous  */
/* (asynchronous). The get the state of the context after an asynchronous     */
/* synchronization, call this function a second time with Cached mode after   */
/* the callback has been invoked.                                             */
/* Inputs:                                                                    */
/*  context: The context to synchronize.                                      */
/*  mode: The type of synchronization to perform.                             */
/*  inputAttribList: NULL or an array of input synchronization attribute /    */
/*                   value pairs terminated with NPAttrib_End.                */
/*  outputAttribList: NULL or an array of output synchronization              */
/*                    attributes / uninitialized value pairs terminated       */
/*                    with NPAttrib_End.                                      */
/*  callback: NULL for synchronous operation or completion callback function  */
/*            for asynchronous operation.                                     */
/*  callbackData: Argument passed to callback function.                       */
/* Outputs:                                                                   */
/*  outputAttribList: The values paired up with each attribute are filled     */
/*                    in on return for synchronous operation.                 */
typedef NPError (*NPDeviceSynchronizeContextPtr)(
    NPP instance,
    NPDeviceContext* context,
    NPDeviceSynchronizationMode mode,
    const int32_t* inputAttribList,
    int32_t* outputAttribList,
    NPDeviceSynchronizeContextCallbackPtr callback,
    void* callbackData);

/* All attributes shared between devices, with the exception of               */
/* NPDeviceContextAttrib_End, have bit 31 set. Device specific attributes     */
/* have the bit clear.                                                        */
enum {
  /* Used to terminate arrays of attribute / value pairs. */
  NPAttrib_End   = 0,

  /* Error status of context. Non-zero means error. Shared by all devices,    */
  /* though error values are device specific.                                 */
  NPAttrib_Error = 0x80000000
};

/* generic device interface */
struct NPDevice {
  NPDeviceQueryCapabilityPtr queryCapability;
  NPDeviceQueryConfigPtr queryConfig;
  NPDeviceInitializeContextPtr initializeContext;
  NPDeviceSetStateContextPtr setStateContext;
  NPDeviceGetStateContextPtr getStateContext;
  NPDeviceFlushContextPtr flushContext;
  NPDeviceDestroyContextPtr destroyContext;
  NPDeviceCreateBufferPtr createBuffer;
  NPDeviceDestroyBufferPtr destroyBuffer;
  NPDeviceMapBufferPtr mapBuffer;

  /* Experimental device API */
  NPDeviceGetNumConfigsPtr getNumConfigs;
  NPDeviceGetConfigAttribsPtr getConfigAttribs;
  NPDeviceCreateContextPtr createContext;
/*  NPDeviceDestroyContextPtr destroyContext; */
  NPDeviceRegisterCallbackPtr registerCallback;
  NPDeviceSynchronizeContextPtr synchronizeContext;
/*  NPDeviceCreateBufferPtr createBuffer; */
/*  NPDeviceDestroyBufferPtr destroyBuffer; */
/*  NPDeviceMapBufferPtr mapBuffer; */
};

/* returns NULL if deviceID unavailable / unrecognized */
typedef NPDevice* (*NPAcquireDevicePtr)(
    NPP instance,
    NPDeviceID device);

/* Updates the number of find results for the current search term.  If
 * there are no matches 0 should be passed in.  Only when the plugin has
 * finished searching should it pass in the final count with finalResult set to
 * true. */
typedef void (*NPNumberOfFindResultsChangedPtr)(
    NPP instance,
    int total,
    bool finalResult);

 /* Updates the index of the currently selected search item. */
typedef void (*NPSelectedFindResultChangedPtr)(
    NPP instance,
    int index);

/* Theming -----------------------------------------------------------------*/
typedef int32_t NPWidgetID;

typedef enum {
  NPWidgetTypeScrollbar = 0
} NPWidgetType;

typedef struct _NPScrollbarCreateParams {
  bool vertical;
} NPScrollbarCreateParams;

typedef struct _NPRect32
{
  uint32_t top;
  uint32_t left;
  uint32_t bottom;
  uint32_t right;
} NPRect32;

typedef struct _NPScrollbarTickMarks {
  uint32_t count;
  NPRect32* tickmarks;
} NPScrollbarTickMarks;

typedef enum {
  NPWidgetPropertyLocation = 0,  // variable is NPRect*.
  NPWidgetPropertyDirtyRect = 1,  // Get only.  variable is NPRec*.
  NPWidgetPropertyScrollbarThickness = 2,  // Get only.  variable is int32_t*.
  NPWidgetPropertyScrollbarValue = 3,  // variable is int32_t*.
  NPWidgetPropertyScrollbarDocumentSize = 4,  // Set only. variable is int32_t*.
  // Set only.  variable is NPScrollbarTickMarks*.
  NPWidgetPropertyScrollbarTickMarks = 5,
  // Set only.  variable is bool* (true for forward, false for backward).
  NPWidgetPropertyScrollbarScrollByLine = 6,
  // Set only.  variable is bool* (true for forward, false for backward).
  NPWidgetPropertyScrollbarScrollByPage = 7,
  // Set only.  variable is bool* (true for forward, false for backward).
  NPWidgetPropertyScrollbarScrollByDocument = 8,
  // Set only.  variable is int32_t* (positive forward, negative  backward).
  NPWidgetPropertyScrollbarScrollByPixels = 9
} NPWidgetProperty;

// Creates a widget.  If it returns NPERR_NO_ERROR then id will contain a unique
// identifer for the widget that's used for the next functions.
typedef NPError (*NPCreateWidgetPtr) (
    NPP instance,
    NPWidgetType type,
    void* params,  // Widget specific.
    NPWidgetID* id);

// Destroys a widget.
typedef NPError (*NPDestroyWidgetPtr) (
    NPP instance,
    NPWidgetID id);

// Paint the dirty rectangle of the given widget into context.
typedef NPError (*NPPaintWidgetPtr) (
    NPP instance,
    NPWidgetID id,
    NPDeviceContext2D* context,
    NPRect* dirty);

// Pass in a pepper event to a plugin.  It'll return true iff it uses it.
typedef bool (*NPHandleWidgetEventPtr) (
    NPP instance,
    NPWidgetID id,
    NPPepperEvent* event);

// Gets a property of the widget.  "value" varies depending on the variable.
typedef NPError (*NPGetWidgetPropertyPtr) (
    NPP instance,
    NPWidgetID id,
    NPWidgetProperty property,
    void* value);

// Sets a property of the widget.
typedef NPError (*NPSetWidgetPropertyPtr) (
    NPP instance,
    NPWidgetID id,
    NPWidgetProperty property,
    void* value);

typedef struct _NPWidgetExtensions {
  NPCreateWidgetPtr createWidget;
  NPDestroyWidgetPtr destroyWidget;
  NPPaintWidgetPtr paintWidget;
  NPHandleWidgetEventPtr handleWidgetEvent;
  NPGetWidgetPropertyPtr getWidgetProperty;
  NPSetWidgetPropertyPtr setWidgetProperty;
} NPWidgetExtensions;

typedef NPWidgetExtensions* (*NPGetWidgetExtensionsPtr)(
    NPP instance);


/* Supports opening files anywhere on the system after prompting the user to
 * pick one.
 *
 * This API is asynchronous. It will return immediately and the user will be
 * prompted in parallel to pick a file. The plugin may continue to receive
 * events while the open file dialog is up, and may continue to paint. Plugins
 * may want to ignore input events between the call and the callback to avoid
 * reentrant behavior. If the return value is not NPERR_NO_ERROR, the callback
 * will NOT be executed.
 *
 * It is an error to call BrowseForFile before a previous call has executed
 * the callback.
 *
 * Setting the flags to "Open" requires that the file exist to allow picking.
 * Setting the flags to "Save" allows selecting nonexistant files (which will
 * then be created), and will prompt the user if they want to overwrite an
 * existing file if it exists.
 *
 * The plugin may specify a comma-separated list of possible mime types in
 * the "extensions" parameter. If no extensions are specified, the dialog box
 * will default to allowing all extensions. The first extension in the list
 * will be the default.
 *
 * TODO(brettw) On Windows the extensions traditionally include a text
 * description with the extension in the popup, do we want to allow this?
 * We should probably also allow the ability to put "All files" in the
 * list on Windows.
 *
 * Once the user has picked a file or has canceled the dialog box, the given
 * callback will be called with the results of the operation and the passed in
 * "user data" pointer. If the user successfully picked a file, the filename
 * will be non-NULL and will contain a pointer to an array of strings, one for
 * each file picked (the first file will be file_paths[0]). This buffer will
 * become invalid as soon as the call completes, so it is the plugin's
 * responsibility to copy the filename(sp if it needs future access to them.
 * A NULL file_paths in the callback means the user canceled the dialog box.
 *
 * The filename will be in UTF-8. It may not actually correspond to the actual
 * file on disk on a Linux system, because we'll do our best to convert it from
 * the filesystem's locale to UTF-8. Instead, the string will be appropriate for
 * displaying to the user which file they picked.
 * */
typedef enum {
  NPChooseFile_Open = 1,
  NPChooseFile_OpenMultiple = 2,
  NPChooseFile_Save = 3
} NPChooseFileMode;
typedef void (*NPChooseFileCallback)(const char** filePaths,
                                     uint32_t pathCount,
                                     void* userData);
typedef NPError (*NPChooseFilePtr)(
    NPP instance,
    const char* mimeTypes,
    NPChooseFileMode mode,
    NPChooseFileCallback callback,
    void* userData);

typedef enum {
  NPCursorTypePointer = 0,
  NPCursorTypeCross = 1,
  NPCursorTypeHand = 2,
  NPCursorTypeIBeam = 3,
  NPCursorTypeWait = 4,
  NPCursorTypeHelp = 5,
  NPCursorTypeEastResize = 6,
  NPCursorTypeNorthResize = 7,
  NPCursorTypeNorthEastResize = 8,
  NPCursorTypeNorthWestResize = 9,
  NPCursorTypeSouthResize = 10,
  NPCursorTypeSouthEastResize = 11,
  NPCursorTypeSouthWestResize = 12,
  NPCursorTypeWestResize = 13,
  NPCursorTypeNorthSouthResize = 14,
  NPCursorTypeEastWestResize = 15,
  NPCursorTypeNorthEastSouthWestResize = 16,
  NPCursorTypeNorthWestSouthEastResize = 17,
  NPCursorTypeColumnResize = 18,
  NPCursorTypeRowResize = 19,
  NPCursorTypeMiddlePanning = 20,
  NPCursorTypeEastPanning = 21,
  NPCursorTypeNorthPanning = 22,
  NPCursorTypeNorthEastPanning = 23,
  NPCursorTypeNorthWestPanning = 24,
  NPCursorTypeSouthPanning = 25,
  NPCursorTypeSouthEastPanning = 26,
  NPCursorTypeSouthWestPanning = 27,
  NPCursorTypeWestPanning = 28,
  NPCursorTypeMove = 29,
  NPCursorTypeVerticalText = 30,
  NPCursorTypeCell = 31,
  NPCursorTypeContextMenu = 32,
  NPCursorTypeAlias = 33,
  NPCursorTypeProgress = 34,
  NPCursorTypeNoDrop = 35,
  NPCursorTypeCopy = 36,
  NPCursorTypeNone = 37,
  NPCursorTypeNotAllowed = 38,
  NPCursorTypeZoomIn = 39,
  NPCursorTypeZoomOut = 40
} NPCursorType;

// Temporary SetCursor API.
typedef NPError (*NPSetCursorPtr)(
    NPP instance,
    NPCursorType type);

/* unique id for each font */
typedef int NPFontID;

typedef enum {
  NPCharsetAnsi = 0,
  NPCharsetDefault = 1,
  NPCharsetSymbol = 2,
  NPCharsetMac = 77,
  NPCharsetShiftJIS = 128,
  NPCharsetHangul = 129,
  NPCharsetJohab = 130,
  NPCharsetGB2312 =134,
  NPCharsetChineseBIG5 = 136,
  NPCharsetGreek = 161,
  NPCharsetTurkish = 162,
  NPCharsetVietnamese = 163,
  NPCharsetHebrew = 177,
  NPCharsetArabic = 178,
  NPCharsetBaltic = 186,
  NPCharsetRussian = 204,
  NPCharsetThai = 222,
  NPCharsetEastEurope = 238,
  NPCharsetOEM = 255
} NPCharset;

typedef enum {
  NPPitchDefault,
  NPPitchFixed
} NPPitch;

typedef enum {
  NPFamilyDefault,
  NPFamilyRoman,
  NPFamilyScript
} NPFamily;

typedef struct _NPFontDescription {
  const char* face;
  int weight;
  bool italic;
  NPPitch pitch;
  NPFamily family;
  NPCharset charset;
} NPFontDescription;

// Return a font which best matches the given properties.
typedef NPError (*NPMatchFontWithFallbackPtr) (
    NPP instance,
    const NPFontDescription* description,
    NPFontID* id);

// Loads a specified font table for the given font.
//   table: the table in *big-endian* format, or 0 for the whole font file.
//   output: a buffer of size output_length that gets the data.  can be 0, in
//     which case output_length will be set to the required size in bytes.
//   output_length: size of output, if it's not 0.
typedef NPError (*GetFontTablePtr) (
    NPP instance,
    NPFontID id,
    uint32_t table,
    void* output,
    size_t* output_length);

// Destroys a font.
typedef NPError (*NPDestroyFontPtr) (
    NPP instance,
    NPFontID id);

typedef struct _NPFontExtensions {
  NPMatchFontWithFallbackPtr matchFontWithFallback;
  GetFontTablePtr getFontTable;
  NPDestroyFontPtr destroyFont;
} NPFontExtensions;

typedef NPFontExtensions* (*NPGetFontExtensionsPtr)(
    NPP instance);

/* Pepper extensions */
struct NPNExtensions {
  /* Device interface acquisition */
  NPAcquireDevicePtr acquireDevice;
  /* Find */
  NPNumberOfFindResultsChangedPtr numberOfFindResultsChanged;
  NPSelectedFindResultChangedPtr selectedFindResultChanged;
  /* File I/O extensions */
  NPChooseFilePtr chooseFile;
  /* Widget */
  NPGetWidgetExtensionsPtr getWidgetExtensions;
  /* Cursor */
  NPSetCursorPtr setCursor;
  /* Font */
  NPGetFontExtensionsPtr getFontExtensions;
};

/* 3D -----------------------------------------------------------------------*/

#define NPPepper3DDevice 2

typedef struct _NPDeviceContext3DConfig {
  int32_t commandBufferSize;
} NPDeviceContext3DConfig;

typedef enum _NPDeviceContext3DError {
  // No error has ocurred.
  NPDeviceContext3DError_NoError,

  // The size of a command was invalid.
  NPDeviceContext3DError_InvalidSize,

  // An offset was out of bounds.
  NPDeviceContext3DError_OutOfBounds,

  // A command was not recognized.
  NPDeviceContext3DError_UnknownCommand,

  // The arguments to a command were invalid.
  NPDeviceContext3DError_InvalidArguments,

  // The 3D context was lost, for example due to a power management event. The
  // context must be destroyed and a new one created.
  NPDeviceContext3DError_LostContext,

  // Any other error.
  NPDeviceContext3DError_GenericError
} NPDeviceContext3DError;

typedef struct _NPDeviceContext3D NPDeviceContext3D;

typedef void (*NPDeviceContext3DRepaintPtr)(NPP npp,
                                            NPDeviceContext3D* context);

// TODO(apatrick): this need not be exposed when we switch over to the new
// device API. It's layout can also be implementation dependent.
typedef struct _NPDeviceContext3D
{
  void* reserved;

  // If true, then a flush will only complete once the get offset has advanced
  // on the GPU thread. If false, then the get offset might have changed but
  // the GPU thread will respond as quickly as possible without guaranteeing
  // having made any progress in executing pending commands. Set to true
  // to ensure that progress is made or when flushing in a loop waiting for the
  // GPU to reach a certain state, for example in advancing beyond a particular
  // token. Set to false when flushing to query the current state, for example
  // whether an error has occurred.
  bool waitForProgress;

  // Buffer in which commands are stored.
  void* commandBuffer;
  int32_t commandBufferSize;

  // Offset in command buffer reader has reached. Synchronized on flush.
  int32_t getOffset;

  // Offset in command buffer writer has reached. Synchronized on flush.
  int32_t putOffset;

  // Last processed token. Synchronized on flush.
  int32_t token;

  // Callback invoked on the main thread when the context must be repainted.
  // TODO(apatrick): move this out of the context struct like the rest of the
  // fields.
  NPDeviceContext3DRepaintPtr repaintCallback;

  // Error status. Synchronized on flush.
  NPDeviceContext3DError error;
} NPDeviceContext3D;


/* Begin 3D specific portion of experimental device API */

/* Device buffer ID reserved for command buffer */
enum {
  NP3DCommandBufferId = 0
};

/* 3D attributes */
enum {
  /* Example GetConfigAttribs attributes. See EGL 1.4 spec. */
  /* These may be passed to GetConfigAttribs. */
  NP3DAttrib_BufferSize        = 0x3020,
  NP3DAttrib_AlphaSize         = 0x3021,
  NP3DAttrib_BlueSize          = 0x3022,
  NP3DAttrib_GreenSize         = 0x3023,
  NP3DAttrib_RedSize           = 0x3024,
  NP3DAttrib_DepthSize         = 0x3025,
  NP3DAttrib_StencilSize       = 0x3026,
  NP3DAttrib_SurfaceType       = 0x3033,

  /* Example CreateContext attributes. See EGL 1.4 spec. */
  /* These may be passed to CreateContext. */
  NP3DAttrib_SwapBehavior       = 0x3093,
  NP3DAttrib_MultisampleResolve = 0x3099,

  /* Size of command buffer in 32-bit entries. */
  /* This may be passed to CreateContext as an input or SynchronizeContext as */
  /* an output. */
  NP3DAttrib_CommandBufferSize  = 0x10000000,

  /* These may be passed to SynchronizeContext. */

  /* Offset in command buffer writer has reached. In / out.*/
  NP3DAttrib_PutOffset,

  /* Offset in command buffer reader has reached. Out only. */
  NP3DAttrib_GetOffset,

  /* Last processed token. Out only. */
  NP3DAttrib_Token
};

/* 3D callbacks */
enum {
  /* This callback is invoked whenever the plugin must repaint everything.    */
  /* This might be because the window manager must repaint a window or        */
  /* the context has been lost, for example a power management event.         */
  NP3DCallback_Repaint = 1
};

/* Flags for NPConfig3DOutAttrib_SurfaceType */
enum {
  NP3DSurfaceType_MultisampleResolveBox = 0x0200,
  NP3DSurfaceType_SwapBehaviorPreserved = 0x0400
};

/* Values for NPConfig3DInAttrib_SwapBehavior */
enum {
  NP3DSwapBehavior_Preserved            = 0x3094,
  NP3DSwapBehavior_Destroyed            = 0x3095
};

/* Values for NPConfig3DInAttrib_MultisampleResolve */
enum {
  NP3DMultisampleResolve_Default        = 0x309A,
  NP3DMultisampleResolve_Box            = 0x309B
};

/* End 3D specific API */

/* Audio --------------------------------------------------------------------*/

#define NPPepperAudioDevice 3

/* min & max sample frame count */
typedef enum {
  NPAudioMinSampleFrameCount = 64,
  NPAudioMaxSampleFrameCount = 32768
} NPAudioSampleFrameCounts;

/* supported sample rates */
typedef enum {
  NPAudioSampleRate44100Hz = 44100,
  NPAudioSampleRate48000Hz = 48000,
  NPAudioSampleRate96000Hz = 96000
} NPAudioSampleRates;

/* supported sample formats */
typedef enum {
  NPAudioSampleTypeInt16   = 0,
  NPAudioSampleTypeFloat32 = 1
} NPAudioSampleTypes;

/* supported channel layouts */
/* there is code that depends on these being the actual number of channels */
typedef enum {
  NPAudioChannelNone     = 0,
  NPAudioChannelMono     = 1,
  NPAudioChannelStereo   = 2,
  NPAudioChannelThree    = 3,
  NPAudioChannelFour     = 4,
  NPAudioChannelFive     = 5,
  NPAudioChannelFiveOne  = 6,
  NPAudioChannelSeven    = 7,
  NPAudioChannelSevenOne = 8
} NPAudioChannels;

/* audio context states */
typedef enum {
  NPAudioContextStateCallback = 0,
  NPAudioContextStateUnderrunCounter = 1
} NPAudioContextStates;

/* audio context state values */
typedef enum {
  NPAudioCallbackStop = 0,
  NPAudioCallbackStart = 1
} NPAudioContextStateValues;

/* audio query capabilities */
typedef enum {
  NPAudioCapabilitySampleRate              = 0,
  NPAudioCapabilitySampleType              = 1,
  NPAudioCapabilitySampleFrameCount        = 2,
  NPAudioCapabilitySampleFrameCount44100Hz = 3,
  NPAudioCapabilitySampleFrameCount48000Hz = 4,
  NPAudioCapabilitySampleFrameCount96000Hz = 5,
  NPAudioCapabilityOutputChannelMap        = 6,
  NPAudioCapabilityInputChannelMap         = 7
} NPAudioCapabilities;

typedef struct _NPDeviceContextAudio NPDeviceContextAudio;

/* user supplied callback function */
typedef void (*NPAudioCallback)(NPDeviceContextAudio *context);

typedef struct _NPDeviceContextAudioConfig {
  int32_t sampleRate;
  int32_t sampleType;
  int32_t outputChannelMap;
  int32_t inputChannelMap;
  int32_t sampleFrameCount;
  uint32_t startThread;
  uint32_t flags;
  NPAudioCallback callback;
  void *userData;
} NPDeviceContextAudioConfig;

struct _NPDeviceContextAudio {
  NPDeviceContextAudioConfig config;
  void *outBuffer;
  void *inBuffer;
  void *reserved;
};

/* Printing related APIs ---------------------------------------------------*/

/* Defines a contiguous range of pages to be printed. Page numbers use a
 * zero-based index. */
typedef struct _NPPrintPageNumberRange {
  int32_t firstPageNumber;
  int32_t lastPageNumber;
} NPPrintPageNumberRange;

/* Being a print operation. Returns the total number of pages to print at the
 * given printableArea size and DPI. printableArea is in points (a point is 1/72
 * of an inch). The plugin is expected to remember the values of printableArea
 * and printerDPI for use in subsequent print interface calls. These values
 * should be cleared in printEnd. */
typedef NPError (*NPPPrintBeginPtr) (
    NPP instance,
    NPRect* printableArea,
    int32_t printerDPI,
    int32_t* numPages);
/* Returns the required raster dimensions for the given page. */
typedef NPError (*NPPGetRasterDimensionsPtr) (
    NPP instance,
    int32_t pageNumber,
    int32_t* widthInPixels,
    int32_t* heightInPixels);
/* Prints the specified page This allows the plugin to print a raster output. */
typedef NPError (*NPPPrintPageRasterPtr) (
    NPP instance,
    int32_t pageNumber,
    NPDeviceContext2D* printSurface);
/* Ends the print operation */
typedef NPError (*NPPPrintEndPtr) (NPP instance);
/* Prints the specified pages as PDF. The plugin allocates the output buffer
 * pointed to by pdf_output using the browser-supplied NPN_MemAlloc function.
 * The caller is expected to free the output buffer upon success.*/
typedef NPError (*NPPrintPagesAsPDFPtr)(NPP instance,
                                        NPPrintPageNumberRange* page_ranges,
                                        int32_t page_range_count,
                                        unsigned char** pdf_output,
                                        int32_t* output_size);


/* TODO(sanjeevr) : Provide a vector interface for printing. We need to decide
 * on a vector format that can support embedded fonts. A vector format will
 * greatly reduce the size of the required output buffer. */

typedef struct _NPPPrintExtensions {
  NPPPrintBeginPtr printBegin;
  NPPGetRasterDimensionsPtr getRasterDimensions;
  NPPPrintPageRasterPtr printPageRaster;
  NPPPrintEndPtr printEnd;
  NPPrintPagesAsPDFPtr printPagesAsPDF;
} NPPPrintExtensions;

/* Returns NULL if the plugin does not support print extensions */
typedef NPPPrintExtensions* (*NPPGetPrintExtensionsPtr)(NPP instance);

/* Find ---------------------------------------------------------------------*/

/* Finds the given UTF-8 text starting at the current selection.  The number of
 * results will be updated asynchronously via numberOfFindResultsChanged.  Note
 * that multiple StartFind calls can happen before StopFind is called in the
 * case of the search term changing. */
typedef NPError (*NPPStartFindPtr) (
    NPP instance,
    const char* text,
    bool caseSensitive);

/* Go to the next/previous result. */
typedef NPError (*NPPSelectFindResultPtr) (
    NPP instance,
    bool forward);

/* Tells the plugin that the find operation has stopped, so it should clear
 * any highlighting. */
typedef NPError (*NPPStopFindPtr) (
    NPP instance);

typedef struct _NPPFindExtensions {
  NPPStartFindPtr startFind;
  NPPSelectFindResultPtr selectFindResult;
  NPPStopFindPtr stopFind;
} NPPFindExtensions;

/* Returns NULL if the plugin does not support find extensions. */
typedef NPPFindExtensions* (*NPPGetFindExtensionsPtr)(NPP instance);

/* Zooms a plugin to the given factor.  If text_only is true, then only the text
 * should be zoomed. */
typedef NPError (*NPPZoomPtr) (
    NPP instance,
    float factor,
    bool text_only);

typedef NPError (*NPPWidgetPropertyChangedPtr) (
    NPP instance,
    NPWidgetID id,
    NPWidgetProperty property);

/* type of selection */
typedef enum {
  NPSelectionTypeAny       = 0,
  NPSelectionTypePlainText = 1,
  NPSelectionTypeHTML      = 2
} NPSelectionType;

/* Gets the selection.  NPERR_GENERIC_ERROR is returned if nothing is selected.
 * 'type' is both an input and output parameter.  The caller can request a
 * specific type, and if the plugin can't provide it, it will return
 * NPERR_GENERIC_ERROR.  Or the caller can specify NPSelectionTypeAny to let the
 * plugin pick the best format for the data.  The result is returned in a buffer
 * that's owned by the caller and which is allocated using NPN_MemAlloc.  If no
 * data is available, NPERR_GENERIC_ERROR is returned. */
typedef NPError (*NPPGetSelectionPtr) (
    NPP instance,
    NPSelectionType* type,
    void** data);

typedef struct _NPPExtensions {
  NPPGetPrintExtensionsPtr getPrintExtensions;
  NPPGetFindExtensionsPtr getFindExtensions;
  NPPZoomPtr zoom;
  NPPWidgetPropertyChangedPtr widgetPropertyChanged;
  NPPGetSelectionPtr getSelection;
} NPPExtensions;

#endif  /* _NP_EXTENSIONS_H_ */
