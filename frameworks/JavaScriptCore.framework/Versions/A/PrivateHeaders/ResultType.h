/*
 * Copyright (C) 2008 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef ResultType_h
#define ResultType_h

namespace JSC {

    struct ResultType {
        friend struct OperandTypes;

        typedef char Type;
        static const Type TypeReusable = 1;
        static const Type TypeInt32    = 2;
        
        static const Type TypeMaybeNumber = 0x04;
        static const Type TypeMaybeString = 0x08;
        static const Type TypeMaybeNull   = 0x10;
        static const Type TypeMaybeBool   = 0x20;
        static const Type TypeMaybeOther  = 0x40;

        static const Type TypeBits = TypeMaybeNumber | TypeMaybeString | TypeMaybeNull | TypeMaybeBool | TypeMaybeOther;

        explicit ResultType(Type type)
            : m_type(type)
        {
        }
        
        bool isReusable()
        {
            return m_type & TypeReusable;
        }

        bool isInt32()
        {
            return m_type & TypeInt32;
        }

        bool definitelyIsNumber()
        {
            return (m_type & TypeBits) == TypeMaybeNumber;
        }
        
        bool definitelyIsString()
        {
            return (m_type & TypeBits) == TypeMaybeString;
        }

        bool mightBeNumber()
        {
            return m_type & TypeMaybeNumber;
        }

        bool isNotNumber()
        {
            return !mightBeNumber();
        }
        
        static ResultType nullType()
        {
            return ResultType(TypeMaybeNull);
        }
        
        static ResultType booleanType()
        {
            return ResultType(TypeMaybeBool);
        }
        
        static ResultType numberType()
        {
            return ResultType(TypeMaybeNumber);
        }
        
        static ResultType numberTypeCanReuse()
        {
            return ResultType(TypeReusable | TypeMaybeNumber);
        }
        
        static ResultType numberTypeCanReuseIsInt32()
        {
            return ResultType(TypeReusable | TypeInt32 | TypeMaybeNumber);
        }
        
        static ResultType stringOrNumberTypeCanReuse()
        {
            return ResultType(TypeReusable | TypeMaybeNumber | TypeMaybeString);
        }
        
        static ResultType stringType()
        {
            return ResultType(TypeMaybeString);
        }
        
        static ResultType unknownType()
        {
            return ResultType(TypeBits);
        }
        
        static ResultType forAdd(ResultType op1, ResultType op2)
        {
            if (op1.definitelyIsNumber() && op2.definitelyIsNumber())
                return numberTypeCanReuse();
            if (op1.definitelyIsString() || op2.definitelyIsString())
                return stringType();
            return stringOrNumberTypeCanReuse();
        }
        
        static ResultType forBitOp()
        {
            return numberTypeCanReuseIsInt32();
        }

    private:
        Type m_type;
    };
    
    struct OperandTypes
    {
        OperandTypes(ResultType first = ResultType::unknownType(), ResultType second = ResultType::unknownType())
        {
            // We have to initialize one of the int to ensure that
            // the entire struct is initialized.
            m_u.i = 0;
            m_u.rds.first = first.m_type;
            m_u.rds.second = second.m_type;
        }
        
        union {
            struct {
                ResultType::Type first;
                ResultType::Type second;
            } rds;
            int i;
        } m_u;

        ResultType first()
        {
            return ResultType(m_u.rds.first);
        }

        ResultType second()
        {
            return ResultType(m_u.rds.second);
        }

        int toInt()
        {
            return m_u.i;
        }
        static OperandTypes fromInt(int value)
        {
            OperandTypes types;
            types.m_u.i = value;
            return types;
        }
    };

} // namespace JSC

#endif // ResultType_h
