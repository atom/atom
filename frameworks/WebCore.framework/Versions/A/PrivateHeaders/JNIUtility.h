/*
 * Copyright (C) 2003, 2004, 2005, 2008, 2009, 2010 Apple Inc. All rights reserved.
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

#ifndef JNIUtility_h
#define JNIUtility_h

#if ENABLE(JAVA_BRIDGE)

#include "JavaType.h"

#if OS(MAC_OS_X)
#include <JavaVM/jni.h>
#else
#include <jni.h>
#endif

namespace JSC {

namespace Bindings {

const char* getCharactersFromJString(jstring);
void releaseCharactersForJString(jstring, const char*);

const char* getCharactersFromJStringInEnv(JNIEnv*, jstring);
void releaseCharactersForJStringInEnv(JNIEnv*, jstring, const char*);
const jchar* getUCharactersFromJStringInEnv(JNIEnv*, jstring);
void releaseUCharactersForJStringInEnv(JNIEnv*, jstring, const jchar*);

JavaType javaTypeFromClassName(const char* name);
JavaType javaTypeFromPrimitiveType(char type);
const char* signatureFromJavaType(JavaType);

jvalue getJNIField(jobject, JavaType, const char* name, const char* signature);
jvalue callJNIMethod(jobject, JavaType returnType, const char* name, const char* signature, jvalue* args);

jmethodID getMethodID(jobject, const char* name, const char* sig);
JNIEnv* getJNIEnv();
JavaVM* getJavaVM();
void setJavaVM(JavaVM*);


template <typename T> struct JNICaller;

template<> struct JNICaller<void> {
    static void callA(jobject obj, jmethodID mid, jvalue* args)
    {
        getJNIEnv()->CallVoidMethodA(obj, mid, args);
    }
    static void callV(jobject obj, jmethodID mid, va_list args)
    {
        getJNIEnv()->CallVoidMethodV(obj, mid, args);
    }
};

template<> struct JNICaller<jobject> {
    static jobject callA(jobject obj, jmethodID mid, jvalue* args)
    {
        return getJNIEnv()->CallObjectMethodA(obj, mid, args);
    }
    static jobject callV(jobject obj, jmethodID mid, va_list args)
    {
        return getJNIEnv()->CallObjectMethodV(obj, mid, args);
    }
};

template<> struct JNICaller<jboolean> {
    static jboolean callA(jobject obj, jmethodID mid, jvalue* args)
    {
        return getJNIEnv()->CallBooleanMethodA(obj, mid, args);
    }
    static jboolean callV(jobject obj, jmethodID mid, va_list args)
    {
        return getJNIEnv()->CallBooleanMethodV(obj, mid, args);
    }
    static jboolean callStaticV(jclass cls, jmethodID mid, va_list args)
    {
        return getJNIEnv()->CallStaticBooleanMethod(cls, mid, args);
    }
};

template<> struct JNICaller<jbyte> {
    static jbyte callA(jobject obj, jmethodID mid, jvalue* args)
    {
        return getJNIEnv()->CallByteMethodA(obj, mid, args);
    }
    static jbyte callV(jobject obj, jmethodID mid, va_list args)
    {
        return getJNIEnv()->CallByteMethodV(obj, mid, args);
    }
};

template<> struct JNICaller<jchar> {
    static jchar callA(jobject obj, jmethodID mid, jvalue* args)
    {
        return getJNIEnv()->CallCharMethodA(obj, mid, args);
    }
    static jchar callV(jobject obj, jmethodID mid, va_list args)
    {
        return getJNIEnv()->CallCharMethodV(obj, mid, args);
    }
};

template<> struct JNICaller<jshort> {
    static jshort callA(jobject obj, jmethodID mid, jvalue* args)
    {
        return getJNIEnv()->CallShortMethodA(obj, mid, args);
    }
    static jshort callV(jobject obj, jmethodID mid, va_list args)
    {
        return getJNIEnv()->CallShortMethodV(obj, mid, args);
    }
};

template<> struct JNICaller<jint> {
    static jint callA(jobject obj, jmethodID mid, jvalue* args)
    {
        return getJNIEnv()->CallIntMethodA(obj, mid, args);
    }
    static jint callV(jobject obj, jmethodID mid, va_list args)
    {
        return getJNIEnv()->CallIntMethodV(obj, mid, args);
    }
};

template<> struct JNICaller<jlong> {
    static jlong callA(jobject obj, jmethodID mid, jvalue* args)
    {
        return getJNIEnv()->CallLongMethodA(obj, mid, args);
    }
    static jlong callV(jobject obj, jmethodID mid, va_list args)
    {
        return getJNIEnv()->CallLongMethodV(obj, mid, args);
    }
};

template<> struct JNICaller<jfloat> {
    static jfloat callA(jobject obj, jmethodID mid, jvalue* args)
    {
        return getJNIEnv()->CallFloatMethodA(obj, mid, args);
    }
    static jfloat callV(jobject obj, jmethodID mid, va_list args)
    {
        return getJNIEnv()->CallFloatMethodV(obj, mid, args);
    }
};

template<> struct JNICaller<jdouble> {
    static jdouble callA(jobject obj, jmethodID mid, jvalue* args)
    {
        return getJNIEnv()->CallDoubleMethodA(obj, mid, args);
    }
    static jdouble callV(jobject obj, jmethodID mid, va_list args)
    {
        return getJNIEnv()->CallDoubleMethodV(obj, mid, args);
    }
};

template<typename T> T callJNIMethodIDA(jobject obj, jmethodID mid, jvalue *args)
{
    return JNICaller<T>::callA(obj, mid, args);
}

template<typename T>
static T callJNIMethodV(jobject obj, const char* name, const char* sig, va_list args)
{
    JavaVM* jvm = getJavaVM();
    JNIEnv* env = getJNIEnv();

    if (obj && jvm && env) {
        jclass cls = env->GetObjectClass(obj);
        if (cls) {
            jmethodID mid = env->GetMethodID(cls, name, sig);
            if (mid) {
                // Avoids references to cls without popping the local frame.
                env->DeleteLocalRef(cls);
                return JNICaller<T>::callV(obj, mid, args);
            }
            LOG_ERROR("Could not find method: %s for %p", name, obj);
            env->ExceptionDescribe();
            env->ExceptionClear();
            fprintf(stderr, "\n");

            env->DeleteLocalRef(cls);
        } else
            LOG_ERROR("Could not find class for %p", obj);
    }

    return 0;
}

template<typename T>
T callJNIMethod(jobject obj, const char* methodName, const char* methodSignature, ...)
{
    va_list args;
    va_start(args, methodSignature);

    T result = callJNIMethodV<T>(obj, methodName, methodSignature, args);

    va_end(args);

    return result;
}

template<typename T>
T callJNIStaticMethod(jclass cls, const char* methodName, const char* methodSignature, ...)
{
    JavaVM* jvm = getJavaVM();
    JNIEnv* env = getJNIEnv();
    va_list args;

    va_start(args, methodSignature);

    T result = 0;

    if (cls && jvm && env) {
        jmethodID mid = env->GetStaticMethodID(cls, methodName, methodSignature);
        if (mid)
            result = JNICaller<T>::callStaticV(cls, mid, args);
        else {
            LOG_ERROR("Could not find method: %s for %p", methodName, cls);
            env->ExceptionDescribe();
            env->ExceptionClear();
            fprintf(stderr, "\n");
        }
    }

    va_end(args);

    return result;
}

} // namespace Bindings

} // namespace JSC

#endif // ENABLE(JAVA_BRIDGE)

#endif // JNIUtility_h
