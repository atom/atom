/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef WTF_Functional_h
#define WTF_Functional_h

#include "Assertions.h"
#include "PassRefPtr.h"
#include "RefPtr.h"
#include "ThreadSafeRefCounted.h"

#if PLATFORM(MAC) && COMPILER_SUPPORTS(BLOCKS)
#include <objc/objc-runtime.h>
#endif

namespace WTF {

// Functional.h provides a very simple way to bind a function pointer and arguments together into a function object
// that can be stored, copied and invoked, similar to how boost::bind and std::bind in C++11.

// Helper class template to determine whether a given type has ref and deref member functions
// with the right type signature.
template<typename T>
class HasRefAndDeref {
    typedef char YesType;
    struct NoType {
        char padding[8];
    };

    struct BaseMixin {
        void deref();
        void ref();
    };

    struct Base : public T, public BaseMixin { };

    template<typename U, U> struct
    TypeChecker { };

    template<typename U>
    static NoType refCheck(U*, TypeChecker<void (BaseMixin::*)(), &U::ref>* = 0);
    static YesType refCheck(...);

    template<typename U>
    static NoType derefCheck(U*, TypeChecker<void (BaseMixin::*)(), &U::deref>* = 0);
    static YesType derefCheck(...);

public:
    static const bool value = sizeof(refCheck(static_cast<Base*>(0))) == sizeof(YesType) && sizeof(derefCheck(static_cast<Base*>(0))) == sizeof(YesType);
};

// A FunctionWrapper is a class template that can wrap a function pointer or a member function pointer and
// provide a unified interface for calling that function.
template<typename>
class FunctionWrapper;

template<typename R>
class FunctionWrapper<R (*)()> {
public:
    typedef R ResultType;
    static const bool shouldRefFirstParameter = false;

    explicit FunctionWrapper(R (*function)())
        : m_function(function)
    {
    }

    R operator()()
    {
        return m_function();
    }

private:
    R (*m_function)();
};

template<typename R, typename P1>
class FunctionWrapper<R (*)(P1)> {
public:
    typedef R ResultType;
    static const bool shouldRefFirstParameter = false;

    explicit FunctionWrapper(R (*function)(P1))
        : m_function(function)
    {
    }

    R operator()(P1 p1)
    {
        return m_function(p1);
    }

private:
    R (*m_function)(P1);
};

template<typename R, typename P1, typename P2>
class FunctionWrapper<R (*)(P1, P2)> {
public:
    typedef R ResultType;
    static const bool shouldRefFirstParameter = false;

    explicit FunctionWrapper(R (*function)(P1, P2))
        : m_function(function)
    {
    }

    R operator()(P1 p1, P2 p2)
    {
        return m_function(p1, p2);
    }

private:
    R (*m_function)(P1, P2);
};

template<typename R, typename P1, typename P2, typename P3>
class FunctionWrapper<R (*)(P1, P2, P3)> {
public:
    typedef R ResultType;
    static const bool shouldRefFirstParameter = false;

    explicit FunctionWrapper(R (*function)(P1, P2, P3))
        : m_function(function)
    {
    }

    R operator()(P1 p1, P2 p2, P3 p3)
    {
        return m_function(p1, p2, p3);
    }

private:
    R (*m_function)(P1, P2, P3);
};

template<typename R, typename C>
class FunctionWrapper<R (C::*)()> {
public:
    typedef R ResultType;
    static const bool shouldRefFirstParameter = HasRefAndDeref<C>::value;

    explicit FunctionWrapper(R (C::*function)())
        : m_function(function)
    {
    }

    R operator()(C* c)
    {
        return (c->*m_function)();
    }

private:
    R (C::*m_function)();
};

template<typename R, typename C, typename P1>
class FunctionWrapper<R (C::*)(P1)> {
public:
    typedef R ResultType;
    static const bool shouldRefFirstParameter = HasRefAndDeref<C>::value;

    explicit FunctionWrapper(R (C::*function)(P1))
        : m_function(function)
    {
    }

    R operator()(C* c, P1 p1)
    {
        return (c->*m_function)(p1);
    }

private:
    R (C::*m_function)(P1);
};

template<typename R, typename C, typename P1, typename P2>
class FunctionWrapper<R (C::*)(P1, P2)> {
public:
    typedef R ResultType;
    static const bool shouldRefFirstParameter = HasRefAndDeref<C>::value;

    explicit FunctionWrapper(R (C::*function)(P1, P2))
        : m_function(function)
    {
    }

    R operator()(C* c, P1 p1, P2 p2)
    {
        return (c->*m_function)(p1, p2);
    }

private:
    R (C::*m_function)(P1, P2);
};

template<typename R, typename C, typename P1, typename P2, typename P3>
class FunctionWrapper<R (C::*)(P1, P2, P3)> {
public:
    typedef R ResultType;
    static const bool shouldRefFirstParameter = HasRefAndDeref<C>::value;

    explicit FunctionWrapper(R (C::*function)(P1, P2, P3))
        : m_function(function)
    {
    }

    R operator()(C* c, P1 p1, P2 p2, P3 p3)
    {
        return (c->*m_function)(p1, p2, p3);
    }

private:
    R (C::*m_function)(P1, P2, P3);
};

template<typename R, typename C, typename P1, typename P2, typename P3, typename P4>
class FunctionWrapper<R (C::*)(P1, P2, P3, P4)> {
public:
    typedef R ResultType;
    static const bool shouldRefFirstParameter = HasRefAndDeref<C>::value;

    explicit FunctionWrapper(R (C::*function)(P1, P2, P3, P4))
        : m_function(function)
    {
    }

    R operator()(C* c, P1 p1, P2 p2, P3 p3, P4 p4)
    {
        return (c->*m_function)(p1, p2, p3, p4);
    }

private:
    R (C::*m_function)(P1, P2, P3, P4);
};

template<typename R, typename C, typename P1, typename P2, typename P3, typename P4, typename P5>
class FunctionWrapper<R (C::*)(P1, P2, P3, P4, P5)> {
public:
    typedef R ResultType;
    static const bool shouldRefFirstParameter = HasRefAndDeref<C>::value;

    explicit FunctionWrapper(R (C::*function)(P1, P2, P3, P4, P5))
        : m_function(function)
    {
    }

    R operator()(C* c, P1 p1, P2 p2, P3 p3, P4 p4, P5 p5)
    {
        return (c->*m_function)(p1, p2, p3, p4, p5);
    }

private:
    R (C::*m_function)(P1, P2, P3, P4, P5);
};

template<typename T, bool shouldRefAndDeref> struct RefAndDeref {
    static void ref(T) { }
    static void deref(T) { }
};

template<typename T> struct RefAndDeref<T*, true> {
    static void ref(T* t) { t->ref(); }
    static void deref(T* t) { t->deref(); }
};

template<typename T> struct ParamStorageTraits {
    typedef T StorageType;

    static StorageType wrap(const T& value) { return value; }
    static const T& unwrap(const StorageType& value) { return value; }
};

template<typename T> struct ParamStorageTraits<PassRefPtr<T> > {
    typedef RefPtr<T> StorageType;

    static StorageType wrap(PassRefPtr<T> value) { return value; }
    static T* unwrap(const StorageType& value) { return value.get(); }
};

template<typename T> struct ParamStorageTraits<RefPtr<T> > {
    typedef RefPtr<T> StorageType;

    static StorageType wrap(RefPtr<T> value) { return value.release(); }
    static T* unwrap(const StorageType& value) { return value.get(); }
};


template<typename> class RetainPtr;

template<typename T> struct ParamStorageTraits<RetainPtr<T> > {
    typedef RetainPtr<T> StorageType;

    static StorageType wrap(const RetainPtr<T>& value) { return value; }
    static typename RetainPtr<T>::PtrType unwrap(const StorageType& value) { return value.get(); }
};

class FunctionImplBase : public ThreadSafeRefCounted<FunctionImplBase> {
public:
    virtual ~FunctionImplBase() { }
};

template<typename>
class FunctionImpl;

template<typename R>
class FunctionImpl<R ()> : public FunctionImplBase {
public:
    virtual R operator()() = 0;
};

template<typename FunctionWrapper, typename FunctionType>
class BoundFunctionImpl;

template<typename FunctionWrapper, typename R>
class BoundFunctionImpl<FunctionWrapper, R ()> : public FunctionImpl<typename FunctionWrapper::ResultType ()> {
public:
    explicit BoundFunctionImpl(FunctionWrapper functionWrapper)
        : m_functionWrapper(functionWrapper)
    {
    }

    virtual R operator()()
    {
        return m_functionWrapper();
    }

private:
    FunctionWrapper m_functionWrapper;
};

template<typename FunctionWrapper, typename R, typename P1>
class BoundFunctionImpl<FunctionWrapper, R (P1)> : public FunctionImpl<typename FunctionWrapper::ResultType ()> {

public:
    BoundFunctionImpl(FunctionWrapper functionWrapper, const P1& p1)
        : m_functionWrapper(functionWrapper)
        , m_p1(ParamStorageTraits<P1>::wrap(p1))
    {
        RefAndDeref<P1, FunctionWrapper::shouldRefFirstParameter>::ref(m_p1);
    }

    ~BoundFunctionImpl()
    {
        RefAndDeref<P1, FunctionWrapper::shouldRefFirstParameter>::deref(m_p1);
    }

    virtual R operator()()
    {
        return m_functionWrapper(ParamStorageTraits<P1>::unwrap(m_p1));
    }

private:
    FunctionWrapper m_functionWrapper;
    typename ParamStorageTraits<P1>::StorageType m_p1;
};

template<typename FunctionWrapper, typename R, typename P1, typename P2>
class BoundFunctionImpl<FunctionWrapper, R (P1, P2)> : public FunctionImpl<typename FunctionWrapper::ResultType ()> {
public:
    BoundFunctionImpl(FunctionWrapper functionWrapper, const P1& p1, const P2& p2)
        : m_functionWrapper(functionWrapper)
        , m_p1(ParamStorageTraits<P1>::wrap(p1))
        , m_p2(ParamStorageTraits<P2>::wrap(p2))
    {
        RefAndDeref<P1, FunctionWrapper::shouldRefFirstParameter>::ref(m_p1);
    }
    
    ~BoundFunctionImpl()
    {
        RefAndDeref<P1, FunctionWrapper::shouldRefFirstParameter>::deref(m_p1);
    }

    virtual typename FunctionWrapper::ResultType operator()()
    {
        return m_functionWrapper(ParamStorageTraits<P1>::unwrap(m_p1), ParamStorageTraits<P2>::unwrap(m_p2));
    }

private:
    FunctionWrapper m_functionWrapper;
    typename ParamStorageTraits<P1>::StorageType m_p1;
    typename ParamStorageTraits<P2>::StorageType m_p2;
};

template<typename FunctionWrapper, typename R, typename P1, typename P2, typename P3>
class BoundFunctionImpl<FunctionWrapper, R (P1, P2, P3)> : public FunctionImpl<typename FunctionWrapper::ResultType ()> {
public:
    BoundFunctionImpl(FunctionWrapper functionWrapper, const P1& p1, const P2& p2, const P3& p3)
        : m_functionWrapper(functionWrapper)
        , m_p1(ParamStorageTraits<P1>::wrap(p1))
        , m_p2(ParamStorageTraits<P2>::wrap(p2))
        , m_p3(ParamStorageTraits<P3>::wrap(p3))
    {
        RefAndDeref<P1, FunctionWrapper::shouldRefFirstParameter>::ref(m_p1);
    }
    
    ~BoundFunctionImpl()
    {
        RefAndDeref<P1, FunctionWrapper::shouldRefFirstParameter>::deref(m_p1);
    }

    virtual typename FunctionWrapper::ResultType operator()()
    {
        return m_functionWrapper(ParamStorageTraits<P1>::unwrap(m_p1), ParamStorageTraits<P2>::unwrap(m_p2), ParamStorageTraits<P3>::unwrap(m_p3));
    }

private:
    FunctionWrapper m_functionWrapper;
    typename ParamStorageTraits<P1>::StorageType m_p1;
    typename ParamStorageTraits<P2>::StorageType m_p2;
    typename ParamStorageTraits<P3>::StorageType m_p3;
};

template<typename FunctionWrapper, typename R, typename P1, typename P2, typename P3, typename P4>
class BoundFunctionImpl<FunctionWrapper, R (P1, P2, P3, P4)> : public FunctionImpl<typename FunctionWrapper::ResultType ()> {
public:
    BoundFunctionImpl(FunctionWrapper functionWrapper, const P1& p1, const P2& p2, const P3& p3, const P4& p4)
        : m_functionWrapper(functionWrapper)
        , m_p1(ParamStorageTraits<P1>::wrap(p1))
        , m_p2(ParamStorageTraits<P2>::wrap(p2))
        , m_p3(ParamStorageTraits<P3>::wrap(p3))
        , m_p4(ParamStorageTraits<P4>::wrap(p4))
    {
        RefAndDeref<P1, FunctionWrapper::shouldRefFirstParameter>::ref(m_p1);
    }
    
    ~BoundFunctionImpl()
    {
        RefAndDeref<P1, FunctionWrapper::shouldRefFirstParameter>::deref(m_p1);
    }

    virtual typename FunctionWrapper::ResultType operator()()
    {
        return m_functionWrapper(ParamStorageTraits<P1>::unwrap(m_p1), ParamStorageTraits<P2>::unwrap(m_p2), ParamStorageTraits<P3>::unwrap(m_p3), ParamStorageTraits<P4>::unwrap(m_p4));
    }

private:
    FunctionWrapper m_functionWrapper;
    typename ParamStorageTraits<P1>::StorageType m_p1;
    typename ParamStorageTraits<P2>::StorageType m_p2;
    typename ParamStorageTraits<P3>::StorageType m_p3;
    typename ParamStorageTraits<P4>::StorageType m_p4;
};

template<typename FunctionWrapper, typename R, typename P1, typename P2, typename P3, typename P4, typename P5>
class BoundFunctionImpl<FunctionWrapper, R (P1, P2, P3, P4, P5)> : public FunctionImpl<typename FunctionWrapper::ResultType ()> {
public:
    BoundFunctionImpl(FunctionWrapper functionWrapper, const P1& p1, const P2& p2, const P3& p3, const P4& p4, const P5& p5)
        : m_functionWrapper(functionWrapper)
        , m_p1(ParamStorageTraits<P1>::wrap(p1))
        , m_p2(ParamStorageTraits<P2>::wrap(p2))
        , m_p3(ParamStorageTraits<P3>::wrap(p3))
        , m_p4(ParamStorageTraits<P4>::wrap(p4))
        , m_p5(ParamStorageTraits<P5>::wrap(p5))
    {
        RefAndDeref<P1, FunctionWrapper::shouldRefFirstParameter>::ref(m_p1);
    }
    
    ~BoundFunctionImpl()
    {
        RefAndDeref<P1, FunctionWrapper::shouldRefFirstParameter>::deref(m_p1);
    }

    virtual typename FunctionWrapper::ResultType operator()()
    {
        return m_functionWrapper(ParamStorageTraits<P1>::unwrap(m_p1), ParamStorageTraits<P2>::unwrap(m_p2), ParamStorageTraits<P3>::unwrap(m_p3), ParamStorageTraits<P4>::unwrap(m_p4), ParamStorageTraits<P5>::unwrap(m_p5));
    }

private:
    FunctionWrapper m_functionWrapper;
    typename ParamStorageTraits<P1>::StorageType m_p1;
    typename ParamStorageTraits<P2>::StorageType m_p2;
    typename ParamStorageTraits<P3>::StorageType m_p3;
    typename ParamStorageTraits<P4>::StorageType m_p4;
    typename ParamStorageTraits<P5>::StorageType m_p5;
};

template<typename FunctionWrapper, typename R, typename P1, typename P2, typename P3, typename P4, typename P5, typename P6>
class BoundFunctionImpl<FunctionWrapper, R (P1, P2, P3, P4, P5, P6)> : public FunctionImpl<typename FunctionWrapper::ResultType ()> {
public:
    BoundFunctionImpl(FunctionWrapper functionWrapper, const P1& p1, const P2& p2, const P3& p3, const P4& p4, const P5& p5, const P6& p6)
        : m_functionWrapper(functionWrapper)
        , m_p1(ParamStorageTraits<P1>::wrap(p1))
        , m_p2(ParamStorageTraits<P2>::wrap(p2))
        , m_p3(ParamStorageTraits<P3>::wrap(p3))
        , m_p4(ParamStorageTraits<P4>::wrap(p4))
        , m_p5(ParamStorageTraits<P5>::wrap(p5))
        , m_p6(ParamStorageTraits<P6>::wrap(p6))
    {
        RefAndDeref<P1, FunctionWrapper::shouldRefFirstParameter>::ref(m_p1);
    }

    ~BoundFunctionImpl()
    {
        RefAndDeref<P1, FunctionWrapper::shouldRefFirstParameter>::deref(m_p1);
    }

    virtual typename FunctionWrapper::ResultType operator()()
    {
        return m_functionWrapper(ParamStorageTraits<P1>::unwrap(m_p1), ParamStorageTraits<P2>::unwrap(m_p2), ParamStorageTraits<P3>::unwrap(m_p3), ParamStorageTraits<P4>::unwrap(m_p4), ParamStorageTraits<P5>::unwrap(m_p5), ParamStorageTraits<P6>::unwrap(m_p6));
    }

private:
    FunctionWrapper m_functionWrapper;
    typename ParamStorageTraits<P1>::StorageType m_p1;
    typename ParamStorageTraits<P2>::StorageType m_p2;
    typename ParamStorageTraits<P3>::StorageType m_p3;
    typename ParamStorageTraits<P4>::StorageType m_p4;
    typename ParamStorageTraits<P5>::StorageType m_p5;
    typename ParamStorageTraits<P6>::StorageType m_p6;
};

class FunctionBase {
public:
    bool isNull() const
    {
        return !m_impl;
    }

protected:
    FunctionBase()
    {
    }

    explicit FunctionBase(PassRefPtr<FunctionImplBase> impl)
        : m_impl(impl)
    {
    }

    template<typename FunctionType> FunctionImpl<FunctionType>* impl() const
    { 
        return static_cast<FunctionImpl<FunctionType>*>(m_impl.get());
    }

private:
    RefPtr<FunctionImplBase> m_impl;
};

template<typename>
class Function;

template<typename R>
class Function<R ()> : public FunctionBase {
public:
    Function()
    {
    }

    Function(PassRefPtr<FunctionImpl<R ()> > impl)
        : FunctionBase(impl)
    {
    }

    R operator()() const
    {
        ASSERT(!isNull());

        return impl<R ()>()->operator()();
    }

#if PLATFORM(MAC) && COMPILER_SUPPORTS(BLOCKS)
    typedef void (^BlockType)();
    operator BlockType() const
    {
        // Declare a RefPtr here so we'll be sure that the underlying FunctionImpl object's
        // lifecycle is managed correctly.
        RefPtr<FunctionImpl<R ()> > functionImpl = impl<R ()>();
        BlockType block = ^{
           functionImpl->operator()();
        };

        // This is equivalent to:
        //
        //   return [[block copy] autorelease];
        //
        // We're using manual objc_msgSend calls here because we don't want to make the entire
        // file Objective-C. It's useful to be able to implicitly convert a Function to
        // a block even in C++ code, since that allows us to do things like:
        //
        //   dispatch_async(queue, bind(...));
        //
        id copiedBlock = objc_msgSend((id)block, sel_registerName("copy"));
        id autoreleasedBlock = objc_msgSend(copiedBlock, sel_registerName("autorelease"));
        return (BlockType)autoreleasedBlock;
    }
#endif
};

template<typename FunctionType>
Function<typename FunctionWrapper<FunctionType>::ResultType ()> bind(FunctionType function)
{
    return Function<typename FunctionWrapper<FunctionType>::ResultType ()>(adoptRef(new BoundFunctionImpl<FunctionWrapper<FunctionType>, typename FunctionWrapper<FunctionType>::ResultType ()>(FunctionWrapper<FunctionType>(function))));
}

template<typename FunctionType, typename A1>
Function<typename FunctionWrapper<FunctionType>::ResultType ()> bind(FunctionType function, const A1& a1)
{
    return Function<typename FunctionWrapper<FunctionType>::ResultType ()>(adoptRef(new BoundFunctionImpl<FunctionWrapper<FunctionType>, typename FunctionWrapper<FunctionType>::ResultType (A1)>(FunctionWrapper<FunctionType>(function), a1)));
}

template<typename FunctionType, typename A1, typename A2>
Function<typename FunctionWrapper<FunctionType>::ResultType ()> bind(FunctionType function, const A1& a1, const A2& a2)
{
    return Function<typename FunctionWrapper<FunctionType>::ResultType ()>(adoptRef(new BoundFunctionImpl<FunctionWrapper<FunctionType>, typename FunctionWrapper<FunctionType>::ResultType (A1, A2)>(FunctionWrapper<FunctionType>(function), a1, a2)));
}

template<typename FunctionType, typename A1, typename A2, typename A3>
Function<typename FunctionWrapper<FunctionType>::ResultType ()> bind(FunctionType function, const A1& a1, const A2& a2, const A3& a3)
{
    return Function<typename FunctionWrapper<FunctionType>::ResultType ()>(adoptRef(new BoundFunctionImpl<FunctionWrapper<FunctionType>, typename FunctionWrapper<FunctionType>::ResultType (A1, A2, A3)>(FunctionWrapper<FunctionType>(function), a1, a2, a3)));
}

template<typename FunctionType, typename A1, typename A2, typename A3, typename A4>
Function<typename FunctionWrapper<FunctionType>::ResultType ()> bind(FunctionType function, const A1& a1, const A2& a2, const A3& a3, const A4& a4)
{
    return Function<typename FunctionWrapper<FunctionType>::ResultType ()>(adoptRef(new BoundFunctionImpl<FunctionWrapper<FunctionType>, typename FunctionWrapper<FunctionType>::ResultType (A1, A2, A3, A4)>(FunctionWrapper<FunctionType>(function), a1, a2, a3, a4)));
}

template<typename FunctionType, typename A1, typename A2, typename A3, typename A4, typename A5>
Function<typename FunctionWrapper<FunctionType>::ResultType ()> bind(FunctionType function, const A1& a1, const A2& a2, const A3& a3, const A4& a4, const A5& a5)
{
    return Function<typename FunctionWrapper<FunctionType>::ResultType ()>(adoptRef(new BoundFunctionImpl<FunctionWrapper<FunctionType>, typename FunctionWrapper<FunctionType>::ResultType (A1, A2, A3, A4, A5)>(FunctionWrapper<FunctionType>(function), a1, a2, a3, a4, a5)));
}

template<typename FunctionType, typename A1, typename A2, typename A3, typename A4, typename A5, typename A6>
Function<typename FunctionWrapper<FunctionType>::ResultType ()> bind(FunctionType function, const A1& a1, const A2& a2, const A3& a3, const A4& a4, const A5& a5, const A6& a6)
{
    return Function<typename FunctionWrapper<FunctionType>::ResultType ()>(adoptRef(new BoundFunctionImpl<FunctionWrapper<FunctionType>, typename FunctionWrapper<FunctionType>::ResultType (A1, A2, A3, A4, A5, A6)>(FunctionWrapper<FunctionType>(function), a1, a2, a3, a4, a5, a6)));
}

}

using WTF::Function;
using WTF::bind;

#endif // WTF_Functional_h
