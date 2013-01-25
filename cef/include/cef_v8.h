// Copyright (c) 2013 Marshall A. Greenblatt. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//    * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//    * Neither the name of Google Inc. nor the name Chromium Embedded
// Framework nor the names of its contributors may be used to endorse
// or promote products derived from this software without specific prior
// written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// ---------------------------------------------------------------------------
//
// The contents of this file must follow a specific format in order to
// support the CEF translator tool. See the translator.README.txt file in the
// tools directory for more information.
//


#ifndef CEF_INCLUDE_CEF_V8_H_
#define CEF_INCLUDE_CEF_V8_H_
#pragma once

#include "include/cef_base.h"
#include "include/cef_browser.h"
#include "include/cef_frame.h"
#include "include/cef_task.h"
#include <vector>

class CefV8Exception;
class CefV8Handler;
class CefV8StackFrame;
class CefV8Value;


///
// Register a new V8 extension with the specified JavaScript extension code and
// handler. Functions implemented by the handler are prototyped using the
// keyword 'native'. The calling of a native function is restricted to the scope
// in which the prototype of the native function is defined. This function may
// only be called on the render process main thread.
//
// Example JavaScript extension code:
// <pre>
//   // create the 'example' global object if it doesn't already exist.
//   if (!example)
//     example = {};
//   // create the 'example.test' global object if it doesn't already exist.
//   if (!example.test)
//     example.test = {};
//   (function() {
//     // Define the function 'example.test.myfunction'.
//     example.test.myfunction = function() {
//       // Call CefV8Handler::Execute() with the function name 'MyFunction'
//       // and no arguments.
//       native function MyFunction();
//       return MyFunction();
//     };
//     // Define the getter function for parameter 'example.test.myparam'.
//     example.test.__defineGetter__('myparam', function() {
//       // Call CefV8Handler::Execute() with the function name 'GetMyParam'
//       // and no arguments.
//       native function GetMyParam();
//       return GetMyParam();
//     });
//     // Define the setter function for parameter 'example.test.myparam'.
//     example.test.__defineSetter__('myparam', function(b) {
//       // Call CefV8Handler::Execute() with the function name 'SetMyParam'
//       // and a single argument.
//       native function SetMyParam();
//       if(b) SetMyParam(b);
//     });
//
//     // Extension definitions can also contain normal JavaScript variables
//     // and functions.
//     var myint = 0;
//     example.test.increment = function() {
//       myint += 1;
//       return myint;
//     };
//   })();
// </pre>
// Example usage in the page:
// <pre>
//   // Call the function.
//   example.test.myfunction();
//   // Set the parameter.
//   example.test.myparam = value;
//   // Get the parameter.
//   value = example.test.myparam;
//   // Call another function.
//   example.test.increment();
// </pre>
///
/*--cef(optional_param=handler)--*/
bool CefRegisterExtension(const CefString& extension_name,
                          const CefString& javascript_code,
                          CefRefPtr<CefV8Handler> handler);


///
// Class representing a V8 context handle. V8 handles can only be accessed from
// the thread on which they are created. Valid threads for creating a V8 handle
// include the render process main thread (TID_RENDERER) and WebWorker threads.
// A task runner for posting tasks on the associated thread can be retrieved via
// the CefV8Context::GetTaskRunner() method.
///
/*--cef(source=library)--*/
class CefV8Context : public virtual CefBase {
 public:
  ///
  // Returns the current (top) context object in the V8 context stack.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Context> GetCurrentContext();

  ///
  // Returns the entered (bottom) context object in the V8 context stack.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Context> GetEnteredContext();

  ///
  // Returns true if V8 is currently inside a context.
  ///
  /*--cef()--*/
  static bool InContext();

  ///
  // Returns the task runner associated with this context. V8 handles can only
  // be accessed from the thread on which they are created. This method can be
  // called on any render process thread.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefTaskRunner> GetTaskRunner() =0;

  ///
  // Returns true if the underlying handle is valid and it can be accessed on
  // the current thread. Do not call any other methods if this method returns
  // false.
  ///
  /*--cef()--*/
  virtual bool IsValid() =0;

  ///
  // Returns the browser for this context. This method will return an empty
  // reference for WebWorker contexts.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefBrowser> GetBrowser() =0;

  ///
  // Returns the frame for this context. This method will return an empty
  // reference for WebWorker contexts.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefFrame> GetFrame() =0;

  ///
  // Returns the global object for this context. The context must be entered
  // before calling this method.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefV8Value> GetGlobal() =0;

  ///
  // Enter this context. A context must be explicitly entered before creating a
  // V8 Object, Array, Function or Date asynchronously. Exit() must be called
  // the same number of times as Enter() before releasing this context. V8
  // objects belong to the context in which they are created. Returns true if
  // the scope was entered successfully.
  ///
  /*--cef()--*/
  virtual bool Enter() =0;

  ///
  // Exit this context. Call this method only after calling Enter(). Returns
  // true if the scope was exited successfully.
  ///
  /*--cef()--*/
  virtual bool Exit() =0;

  ///
  // Returns true if this object is pointing to the same handle as |that|
  // object.
  ///
  /*--cef()--*/
  virtual bool IsSame(CefRefPtr<CefV8Context> that) =0;

  ///
  // Evaluates the specified JavaScript code using this context's global object.
  // On success |retval| will be set to the return value, if any, and the
  // function will return true. On failure |exception| will be set to the
  // exception, if any, and the function will return false.
  ///
  /*--cef()--*/
  virtual bool Eval(const CefString& code,
                    CefRefPtr<CefV8Value>& retval,
                    CefRefPtr<CefV8Exception>& exception) =0;
};


typedef std::vector<CefRefPtr<CefV8Value> > CefV8ValueList;

///
// Interface that should be implemented to handle V8 function calls. The methods
// of this class will be called on the thread associated with the V8 function.
///
/*--cef(source=client)--*/
class CefV8Handler : public virtual CefBase {
 public:
  ///
  // Handle execution of the function identified by |name|. |object| is the
  // receiver ('this' object) of the function. |arguments| is the list of
  // arguments passed to the function. If execution succeeds set |retval| to the
  // function return value. If execution fails set |exception| to the exception
  // that will be thrown. Return true if execution was handled.
  ///
  /*--cef()--*/
  virtual bool Execute(const CefString& name,
                       CefRefPtr<CefV8Value> object,
                       const CefV8ValueList& arguments,
                       CefRefPtr<CefV8Value>& retval,
                       CefString& exception) =0;
};

///
// Interface that should be implemented to handle V8 accessor calls. Accessor
// identifiers are registered by calling CefV8Value::SetValue(). The methods
// of this class will be called on the thread associated with the V8 accessor.
///
/*--cef(source=client)--*/
class CefV8Accessor : public virtual CefBase {
 public:
  ///
  // Handle retrieval the accessor value identified by |name|. |object| is the
  // receiver ('this' object) of the accessor. If retrieval succeeds set
  // |retval| to the return value. If retrieval fails set |exception| to the
  // exception that will be thrown. Return true if accessor retrieval was
  // handled.
  ///
  /*--cef()--*/
  virtual bool Get(const CefString& name,
                   const CefRefPtr<CefV8Value> object,
                   CefRefPtr<CefV8Value>& retval,
                   CefString& exception) =0;

  ///
  // Handle assignment of the accessor value identified by |name|. |object| is
  // the receiver ('this' object) of the accessor. |value| is the new value
  // being assigned to the accessor. If assignment fails set |exception| to the
  // exception that will be thrown. Return true if accessor assignment was
  // handled.
  ///
  /*--cef()--*/
  virtual bool Set(const CefString& name,
                   const CefRefPtr<CefV8Value> object,
                   const CefRefPtr<CefV8Value> value,
                   CefString& exception) =0;
};

///
// Class representing a V8 exception. The methods of this class may be called on
// any render process thread.
///
/*--cef(source=library)--*/
class CefV8Exception : public virtual CefBase {
 public:
  ///
  // Returns the exception message.
  ///
  /*--cef()--*/
  virtual CefString GetMessage() =0;

  ///
  // Returns the line of source code that the exception occurred within.
  ///
  /*--cef()--*/
  virtual CefString GetSourceLine() =0;

  ///
  // Returns the resource name for the script from where the function causing
  // the error originates.
  ///
  /*--cef()--*/
  virtual CefString GetScriptResourceName() =0;

  ///
  // Returns the 1-based number of the line where the error occurred or 0 if the
  // line number is unknown.
  ///
  /*--cef()--*/
  virtual int GetLineNumber() =0;

  ///
  // Returns the index within the script of the first character where the error
  // occurred.
  ///
  /*--cef()--*/
  virtual int GetStartPosition() =0;

  ///
  // Returns the index within the script of the last character where the error
  // occurred.
  ///
  /*--cef()--*/
  virtual int GetEndPosition() =0;

  ///
  // Returns the index within the line of the first character where the error
  // occurred.
  ///
  /*--cef()--*/
  virtual int GetStartColumn() =0;

  ///
  // Returns the index within the line of the last character where the error
  // occurred.
  ///
  /*--cef()--*/
  virtual int GetEndColumn() =0;
};

///
// Class representing a V8 value handle. V8 handles can only be accessed from
// the thread on which they are created. Valid threads for creating a V8 handle
// include the render process main thread (TID_RENDERER) and WebWorker threads.
// A task runner for posting tasks on the associated thread can be retrieved via
// the CefV8Context::GetTaskRunner() method.
///
/*--cef(source=library)--*/
class CefV8Value : public virtual CefBase {
 public:
  typedef cef_v8_accesscontrol_t AccessControl;
  typedef cef_v8_propertyattribute_t PropertyAttribute;

  ///
  // Create a new CefV8Value object of type undefined.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateUndefined();

  ///
  // Create a new CefV8Value object of type null.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateNull();

  ///
  // Create a new CefV8Value object of type bool.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateBool(bool value);

  ///
  // Create a new CefV8Value object of type int.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateInt(int32 value);

  ///
  // Create a new CefV8Value object of type unsigned int.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateUInt(uint32 value);

  ///
  // Create a new CefV8Value object of type double.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateDouble(double value);

  ///
  // Create a new CefV8Value object of type Date. This method should only be
  // called from within the scope of a CefV8ContextHandler, CefV8Handler or
  // CefV8Accessor callback, or in combination with calling Enter() and Exit()
  // on a stored CefV8Context reference.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateDate(const CefTime& date);

  ///
  // Create a new CefV8Value object of type string.
  ///
  /*--cef(optional_param=value)--*/
  static CefRefPtr<CefV8Value> CreateString(const CefString& value);

  ///
  // Create a new CefV8Value object of type object with optional accessor. This
  // method should only be called from within the scope of a
  // CefV8ContextHandler, CefV8Handler or CefV8Accessor callback, or in
  // combination with calling Enter() and Exit() on a stored CefV8Context
  // reference.
  ///
  /*--cef(optional_param=accessor)--*/
  static CefRefPtr<CefV8Value> CreateObject(CefRefPtr<CefV8Accessor> accessor);

  ///
  // Create a new CefV8Value object of type array with the specified |length|.
  // If |length| is negative the returned array will have length 0. This method
  // should only be called from within the scope of a CefV8ContextHandler,
  // CefV8Handler or CefV8Accessor callback, or in combination with calling
  // Enter() and Exit() on a stored CefV8Context reference.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateArray(int length);

  ///
  // Create a new CefV8Value object of type function. This method should only be
  // called from within the scope of a CefV8ContextHandler, CefV8Handler or
  // CefV8Accessor callback, or in combination with calling Enter() and Exit()
  // on a stored CefV8Context reference.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8Value> CreateFunction(const CefString& name,
                                              CefRefPtr<CefV8Handler> handler);

  ///
  // Returns true if the underlying handle is valid and it can be accessed on
  // the current thread. Do not call any other methods if this method returns
  // false.
  ///
  /*--cef()--*/
  virtual bool IsValid() =0;

  ///
  // True if the value type is undefined.
  ///
  /*--cef()--*/
  virtual bool IsUndefined() =0;

  ///
  // True if the value type is null.
  ///
  /*--cef()--*/
  virtual bool IsNull() =0;

  ///
  // True if the value type is bool.
  ///
  /*--cef()--*/
  virtual bool IsBool() =0;

  ///
  // True if the value type is int.
  ///
  /*--cef()--*/
  virtual bool IsInt() =0;

  ///
  // True if the value type is unsigned int.
  ///
  /*--cef()--*/
  virtual bool IsUInt() =0;

  ///
  // True if the value type is double.
  ///
  /*--cef()--*/
  virtual bool IsDouble() =0;

  ///
  // True if the value type is Date.
  ///
  /*--cef()--*/
  virtual bool IsDate() =0;

  ///
  // True if the value type is string.
  ///
  /*--cef()--*/
  virtual bool IsString() =0;

  ///
  // True if the value type is object.
  ///
  /*--cef()--*/
  virtual bool IsObject() =0;

  ///
  // True if the value type is array.
  ///
  /*--cef()--*/
  virtual bool IsArray() =0;

  ///
  // True if the value type is function.
  ///
  /*--cef()--*/
  virtual bool IsFunction() =0;

  ///
  // Returns true if this object is pointing to the same handle as |that|
  // object.
  ///
  /*--cef()--*/
  virtual bool IsSame(CefRefPtr<CefV8Value> that) =0;

  ///
  // Return a bool value.  The underlying data will be converted to if
  // necessary.
  ///
  /*--cef()--*/
  virtual bool GetBoolValue() =0;

  ///
  // Return an int value.  The underlying data will be converted to if
  // necessary.
  ///
  /*--cef()--*/
  virtual int32 GetIntValue() =0;

  ///
  // Return an unisgned int value.  The underlying data will be converted to if
  // necessary.
  ///
  /*--cef()--*/
  virtual uint32 GetUIntValue() =0;

  ///
  // Return a double value.  The underlying data will be converted to if
  // necessary.
  ///
  /*--cef()--*/
  virtual double GetDoubleValue() =0;

  ///
  // Return a Date value.  The underlying data will be converted to if
  // necessary.
  ///
  /*--cef()--*/
  virtual CefTime GetDateValue() =0;

  ///
  // Return a string value.  The underlying data will be converted to if
  // necessary.
  ///
  /*--cef()--*/
  virtual CefString GetStringValue() =0;


  // OBJECT METHODS - These methods are only available on objects. Arrays and
  // functions are also objects. String- and integer-based keys can be used
  // interchangably with the framework converting between them as necessary.

  ///
  // Returns true if this is a user created object.
  ///
  /*--cef()--*/
  virtual bool IsUserCreated() =0;

  ///
  // Returns true if the last method call resulted in an exception. This
  // attribute exists only in the scope of the current CEF value object.
  ///
  /*--cef()--*/
  virtual bool HasException() =0;

  ///
  // Returns the exception resulting from the last method call. This attribute
  // exists only in the scope of the current CEF value object.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefV8Exception> GetException() =0;

  ///
  // Clears the last exception and returns true on success.
  ///
  /*--cef()--*/
  virtual bool ClearException() =0;

  ///
  // Returns true if this object will re-throw future exceptions. This attribute
  // exists only in the scope of the current CEF value object.
  ///
  /*--cef()--*/
  virtual bool WillRethrowExceptions() =0;

  ///
  // Set whether this object will re-throw future exceptions. By default
  // exceptions are not re-thrown. If a exception is re-thrown the current
  // context should not be accessed again until after the exception has been
  // caught and not re-thrown. Returns true on success. This attribute exists
  // only in the scope of the current CEF value object.
  ///
  /*--cef()--*/
  virtual bool SetRethrowExceptions(bool rethrow) =0;

  ///
  // Returns true if the object has a value with the specified identifier.
  ///
  /*--cef(capi_name=has_value_bykey,optional_param=key)--*/
  virtual bool HasValue(const CefString& key) =0;

  ///
  // Returns true if the object has a value with the specified identifier.
  ///
  /*--cef(capi_name=has_value_byindex,index_param=index)--*/
  virtual bool HasValue(int index) =0;

  ///
  // Deletes the value with the specified identifier and returns true on
  // success. Returns false if this method is called incorrectly or an exception
  // is thrown. For read-only and don't-delete values this method will return
  // true even though deletion failed.
  ///
  /*--cef(capi_name=delete_value_bykey,optional_param=key)--*/
  virtual bool DeleteValue(const CefString& key) =0;

  ///
  // Deletes the value with the specified identifier and returns true on
  // success. Returns false if this method is called incorrectly, deletion fails
  // or an exception is thrown. For read-only and don't-delete values this
  // method will return true even though deletion failed.
  ///
  /*--cef(capi_name=delete_value_byindex,index_param=index)--*/
  virtual bool DeleteValue(int index) =0;

  ///
  // Returns the value with the specified identifier on success. Returns NULL
  // if this method is called incorrectly or an exception is thrown.
  ///
  /*--cef(capi_name=get_value_bykey,optional_param=key)--*/
  virtual CefRefPtr<CefV8Value> GetValue(const CefString& key) =0;

  ///
  // Returns the value with the specified identifier on success. Returns NULL
  // if this method is called incorrectly or an exception is thrown.
  ///
  /*--cef(capi_name=get_value_byindex,index_param=index)--*/
  virtual CefRefPtr<CefV8Value> GetValue(int index) =0;

  ///
  // Associates a value with the specified identifier and returns true on
  // success. Returns false if this method is called incorrectly or an exception
  // is thrown. For read-only values this method will return true even though
  // assignment failed.
  ///
  /*--cef(capi_name=set_value_bykey,optional_param=key)--*/
  virtual bool SetValue(const CefString& key, CefRefPtr<CefV8Value> value,
                        PropertyAttribute attribute) =0;

  ///
  // Associates a value with the specified identifier and returns true on
  // success. Returns false if this method is called incorrectly or an exception
  // is thrown. For read-only values this method will return true even though
  // assignment failed.
  ///
  /*--cef(capi_name=set_value_byindex,index_param=index)--*/
  virtual bool SetValue(int index, CefRefPtr<CefV8Value> value) =0;

  ///
  // Registers an identifier and returns true on success. Access to the
  // identifier will be forwarded to the CefV8Accessor instance passed to
  // CefV8Value::CreateObject(). Returns false if this method is called
  // incorrectly or an exception is thrown. For read-only values this method
  // will return true even though assignment failed.
  ///
  /*--cef(capi_name=set_value_byaccessor,optional_param=key)--*/
  virtual bool SetValue(const CefString& key, AccessControl settings,
                        PropertyAttribute attribute) =0;

  ///
  // Read the keys for the object's values into the specified vector. Integer-
  // based keys will also be returned as strings.
  ///
  /*--cef()--*/
  virtual bool GetKeys(std::vector<CefString>& keys) =0;

  ///
  // Sets the user data for this object and returns true on success. Returns
  // false if this method is called incorrectly. This method can only be called
  // on user created objects.
  ///
  /*--cef(optional_param=user_data)--*/
  virtual bool SetUserData(CefRefPtr<CefBase> user_data) =0;

  ///
  // Returns the user data, if any, assigned to this object.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefBase> GetUserData() =0;

  ///
  // Returns the amount of externally allocated memory registered for the
  // object.
  ///
  /*--cef()--*/
  virtual int GetExternallyAllocatedMemory() =0;

  ///
  // Adjusts the amount of registered external memory for the object. Used to
  // give V8 an indication of the amount of externally allocated memory that is
  // kept alive by JavaScript objects. V8 uses this information to decide when
  // to perform global garbage collection. Each CefV8Value tracks the amount of
  // external memory associated with it and automatically decreases the global
  // total by the appropriate amount on its destruction. |change_in_bytes|
  // specifies the number of bytes to adjust by. This method returns the number
  // of bytes associated with the object after the adjustment. This method can
  // only be called on user created objects.
  ///
  /*--cef()--*/
  virtual int AdjustExternallyAllocatedMemory(int change_in_bytes) =0;


  // ARRAY METHODS - These methods are only available on arrays.

  ///
  // Returns the number of elements in the array.
  ///
  /*--cef()--*/
  virtual int GetArrayLength() =0;


  // FUNCTION METHODS - These methods are only available on functions.

  ///
  // Returns the function name.
  ///
  /*--cef()--*/
  virtual CefString GetFunctionName() =0;

  ///
  // Returns the function handler or NULL if not a CEF-created function.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefV8Handler> GetFunctionHandler() =0;

  ///
  // Execute the function using the current V8 context. This method should only
  // be called from within the scope of a CefV8Handler or CefV8Accessor
  // callback, or in combination with calling Enter() and Exit() on a stored
  // CefV8Context reference. |object| is the receiver ('this' object) of the
  // function. If |object| is empty the current context's global object will be
  // used. |arguments| is the list of arguments that will be passed to the
  // function. Returns the function return value on success. Returns NULL if
  // this method is called incorrectly or an exception is thrown.
  ///
  /*--cef(optional_param=object)--*/
  virtual CefRefPtr<CefV8Value> ExecuteFunction(
      CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments) =0;

  ///
  // Execute the function using the specified V8 context. |object| is the
  // receiver ('this' object) of the function. If |object| is empty the
  // specified context's global object will be used. |arguments| is the list of
  // arguments that will be passed to the function. Returns the function return
  // value on success. Returns NULL if this method is called incorrectly or an
  // exception is thrown.
  ///
  /*--cef(optional_param=object)--*/
  virtual CefRefPtr<CefV8Value> ExecuteFunctionWithContext(
      CefRefPtr<CefV8Context> context,
      CefRefPtr<CefV8Value> object,
      const CefV8ValueList& arguments) =0;
};

///
// Class representing a V8 stack trace handle. V8 handles can only be accessed
// from the thread on which they are created. Valid threads for creating a V8
// handle include the render process main thread (TID_RENDERER) and WebWorker
// threads. A task runner for posting tasks on the associated thread can be
// retrieved via the CefV8Context::GetTaskRunner() method.
///
/*--cef(source=library)--*/
class CefV8StackTrace : public virtual CefBase {
 public:
  ///
  // Returns the stack trace for the currently active context. |frame_limit| is
  // the maximum number of frames that will be captured.
  ///
  /*--cef()--*/
  static CefRefPtr<CefV8StackTrace> GetCurrent(int frame_limit);

  ///
  // Returns true if the underlying handle is valid and it can be accessed on
  // the current thread. Do not call any other methods if this method returns
  // false.
  ///
  /*--cef()--*/
  virtual bool IsValid() =0;

  ///
  // Returns the number of stack frames.
  ///
  /*--cef()--*/
  virtual int GetFrameCount() =0;

  ///
  // Returns the stack frame at the specified 0-based index.
  ///
  /*--cef()--*/
  virtual CefRefPtr<CefV8StackFrame> GetFrame(int index) =0;
};

///
// Class representing a V8 stack frame handle. V8 handles can only be accessed
// from the thread on which they are created. Valid threads for creating a V8
// handle include the render process main thread (TID_RENDERER) and WebWorker
// threads. A task runner for posting tasks on the associated thread can be
// retrieved via the CefV8Context::GetTaskRunner() method.
///
/*--cef(source=library)--*/
class CefV8StackFrame : public virtual CefBase {
 public:
  ///
  // Returns true if the underlying handle is valid and it can be accessed on
  // the current thread. Do not call any other methods if this method returns
  // false.
  ///
  /*--cef()--*/
  virtual bool IsValid() =0;

  ///
  // Returns the name of the resource script that contains the function.
  ///
  /*--cef()--*/
  virtual CefString GetScriptName() =0;

  ///
  // Returns the name of the resource script that contains the function or the
  // sourceURL value if the script name is undefined and its source ends with
  // a "//@ sourceURL=..." string.
  ///
  /*--cef()--*/
  virtual CefString GetScriptNameOrSourceURL() =0;

  ///
  // Returns the name of the function.
  ///
  /*--cef()--*/
  virtual CefString GetFunctionName() =0;

  ///
  // Returns the 1-based line number for the function call or 0 if unknown.
  ///
  /*--cef()--*/
  virtual int GetLineNumber() =0;

  ///
  // Returns the 1-based column offset on the line for the function call or 0 if
  // unknown.
  ///
  /*--cef()--*/
  virtual int GetColumn() =0;

  ///
  // Returns true if the function was compiled using eval().
  ///
  /*--cef()--*/
  virtual bool IsEval() =0;

  ///
  // Returns true if the function was called as a constructor via "new".
  ///
  /*--cef()--*/
  virtual bool IsConstructor() =0;
};

#endif  // CEF_INCLUDE_CEF_V8_H_
