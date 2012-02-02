/*
 *  Copyright (C) 1999-2000 Harri Porten (porten@kde.org)
 *  Copyright (C) 2001 Peter Kelly (pmk@post.com)
 *  Copyright (C) 2003, 2004, 2005, 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
 *  Copyright (C) 2007 Cameron Zwarich (cwzwarich@uwaterloo.ca)
 *  Copyright (C) 2007 Maks Orlovich
 *  Copyright (C) 2007 Eric Seidel <eric@webkit.org>
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public License
 *  along with this library; see the file COPYING.LIB.  If not, write to
 *  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 *  Boston, MA 02110-1301, USA.
 *
 */

#ifndef Nodes_h
#define Nodes_h

#include "Error.h"
#include "JITCode.h"
#include "Opcode.h"
#include "ParserArena.h"
#include "ResultType.h"
#include "SourceCode.h"
#include "SymbolTable.h"
#include <wtf/MathExtras.h>

namespace JSC {

    class ArgumentListNode;
    class BytecodeGenerator;
    class FunctionBodyNode;
    class Label;
    class PropertyListNode;
    class ReadModifyResolveNode;
    class RegisterID;
    class ScopeChainNode;
    class ScopeNode;

    typedef unsigned CodeFeatures;

    const CodeFeatures NoFeatures = 0;
    const CodeFeatures EvalFeature = 1 << 0;
    const CodeFeatures ClosureFeature = 1 << 1;
    const CodeFeatures AssignFeature = 1 << 2;
    const CodeFeatures ArgumentsFeature = 1 << 3;
    const CodeFeatures WithFeature = 1 << 4;
    const CodeFeatures CatchFeature = 1 << 5;
    const CodeFeatures ThisFeature = 1 << 6;
    const CodeFeatures StrictModeFeature = 1 << 7;
    const CodeFeatures ShadowsArgumentsFeature = 1 << 8;
    
    
    const CodeFeatures AllFeatures = EvalFeature | ClosureFeature | AssignFeature | ArgumentsFeature | WithFeature | CatchFeature | ThisFeature | StrictModeFeature | ShadowsArgumentsFeature;

    enum Operator {
        OpEqual,
        OpPlusEq,
        OpMinusEq,
        OpMultEq,
        OpDivEq,
        OpPlusPlus,
        OpMinusMinus,
        OpAndEq,
        OpXOrEq,
        OpOrEq,
        OpModEq,
        OpLShift,
        OpRShift,
        OpURShift
    };
    
    enum LogicalOperator {
        OpLogicalAnd,
        OpLogicalOr
    };

    typedef HashSet<RefPtr<StringImpl>, IdentifierRepHash> IdentifierSet;

    namespace DeclarationStacks {
        enum VarAttrs { IsConstant = 1, HasInitializer = 2 };
        typedef Vector<std::pair<const Identifier*, unsigned> > VarStack;
        typedef Vector<FunctionBodyNode*> FunctionStack;
    }

    struct SwitchInfo {
        enum SwitchType { SwitchNone, SwitchImmediate, SwitchCharacter, SwitchString };
        uint32_t bytecodeOffset;
        SwitchType switchType;
    };

    class ParserArenaFreeable {
    public:
        // ParserArenaFreeable objects are are freed when the arena is deleted.
        // Destructors are not called. Clients must not call delete on such objects.
        void* operator new(size_t, JSGlobalData*);
    };

    class ParserArenaDeletable {
    public:
        virtual ~ParserArenaDeletable() { }

        // ParserArenaDeletable objects are deleted when the arena is deleted.
        // Clients must not call delete directly on such objects.
        void* operator new(size_t, JSGlobalData*);
    };

    template <typename T>
    struct ParserArenaData : ParserArenaDeletable {
        T data;
    };

    class ParserArenaRefCounted : public RefCounted<ParserArenaRefCounted> {
    protected:
        ParserArenaRefCounted(JSGlobalData*);

    public:
        virtual ~ParserArenaRefCounted()
        {
            ASSERT(deletionHasBegun());
        }
    };

    class Node : public ParserArenaFreeable {
    protected:
        Node(int);

    public:
        virtual ~Node() { }

        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* destination = 0) = 0;

        int lineNo() const { return m_lineNumber; }

    protected:
        int m_lineNumber;
    };

    class ExpressionNode : public Node {
    protected:
        ExpressionNode(int, ResultType = ResultType::unknownType());

    public:
        virtual bool isNumber() const { return false; }
        virtual bool isString() const { return false; }
        virtual bool isNull() const { return false; }
        virtual bool isPure(BytecodeGenerator&) const { return false; }        
        virtual bool isLocation() const { return false; }
        virtual bool isResolveNode() const { return false; }
        virtual bool isBracketAccessorNode() const { return false; }
        virtual bool isDotAccessorNode() const { return false; }
        virtual bool isFuncExprNode() const { return false; }
        virtual bool isCommaNode() const { return false; }
        virtual bool isSimpleArray() const { return false; }
        virtual bool isAdd() const { return false; }
        virtual bool isSubtract() const { return false; }
        virtual bool hasConditionContextCodegen() const { return false; }

        virtual void emitBytecodeInConditionContext(BytecodeGenerator&, Label*, Label*, bool) { ASSERT_NOT_REACHED(); }

        virtual ExpressionNode* stripUnaryPlus() { return this; }

        ResultType resultDescriptor() const { return m_resultType; }

    private:
        ResultType m_resultType;
    };

    class StatementNode : public Node {
    protected:
        StatementNode(int);

    public:
        JS_EXPORT_PRIVATE void setLoc(int firstLine, int lastLine);
        int firstLine() const { return lineNo(); }
        int lastLine() const { return m_lastLine; }

        virtual bool isEmptyStatement() const { return false; }
        virtual bool isReturnNode() const { return false; }
        virtual bool isExprStatement() const { return false; }

        virtual bool isBlock() const { return false; }

    private:
        int m_lastLine;
    };

    class NullNode : public ExpressionNode {
    public:
        NullNode(int);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        virtual bool isNull() const { return true; }
    };

    class BooleanNode : public ExpressionNode {
    public:
        BooleanNode(int, bool value);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        virtual bool isPure(BytecodeGenerator&) const { return true; }

        bool m_value;
    };

    class NumberNode : public ExpressionNode {
    public:
        NumberNode(int, double value);

        double value() const { return m_value; }
        void setValue(double value) { m_value = value; }

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        virtual bool isNumber() const { return true; }
        virtual bool isPure(BytecodeGenerator&) const { return true; }

        double m_value;
    };

    class StringNode : public ExpressionNode {
    public:
        StringNode(int, const Identifier&);

        const Identifier& value() { return m_value; }

    private:
        virtual bool isPure(BytecodeGenerator&) const { return true; }

        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);
        
        virtual bool isString() const { return true; }

        const Identifier& m_value;
    };
    
    class ThrowableExpressionData {
    public:
        ThrowableExpressionData()
            : m_divot(static_cast<uint32_t>(-1))
            , m_startOffset(static_cast<uint16_t>(-1))
            , m_endOffset(static_cast<uint16_t>(-1))
        {
        }
        
        ThrowableExpressionData(unsigned divot, unsigned startOffset, unsigned endOffset)
            : m_divot(divot)
            , m_startOffset(startOffset)
            , m_endOffset(endOffset)
        {
        }
        
        void setExceptionSourceCode(unsigned divot, unsigned startOffset, unsigned endOffset)
        {
            m_divot = divot;
            m_startOffset = startOffset;
            m_endOffset = endOffset;
        }

        uint32_t divot() const { return m_divot; }
        uint16_t startOffset() const { return m_startOffset; }
        uint16_t endOffset() const { return m_endOffset; }

    protected:
        RegisterID* emitThrowReferenceError(BytecodeGenerator&, const UString& message);

    private:
        uint32_t m_divot;
        uint16_t m_startOffset;
        uint16_t m_endOffset;
    };

    class ThrowableSubExpressionData : public ThrowableExpressionData {
    public:
        ThrowableSubExpressionData()
            : m_subexpressionDivotOffset(0)
            , m_subexpressionEndOffset(0)
        {
        }

        ThrowableSubExpressionData(unsigned divot, unsigned startOffset, unsigned endOffset)
            : ThrowableExpressionData(divot, startOffset, endOffset)
            , m_subexpressionDivotOffset(0)
            , m_subexpressionEndOffset(0)
        {
        }

        void setSubexpressionInfo(uint32_t subexpressionDivot, uint16_t subexpressionOffset)
        {
            ASSERT(subexpressionDivot <= divot());
            if ((divot() - subexpressionDivot) & ~0xFFFF) // Overflow means we can't do this safely, so just point at the primary divot
                return;
            m_subexpressionDivotOffset = divot() - subexpressionDivot;
            m_subexpressionEndOffset = subexpressionOffset;
        }

    protected:
        uint16_t m_subexpressionDivotOffset;
        uint16_t m_subexpressionEndOffset;
    };
    
    class ThrowablePrefixedSubExpressionData : public ThrowableExpressionData {
    public:
        ThrowablePrefixedSubExpressionData()
            : m_subexpressionDivotOffset(0)
            , m_subexpressionStartOffset(0)
        {
        }

        ThrowablePrefixedSubExpressionData(unsigned divot, unsigned startOffset, unsigned endOffset)
            : ThrowableExpressionData(divot, startOffset, endOffset)
            , m_subexpressionDivotOffset(0)
            , m_subexpressionStartOffset(0)
        {
        }

        void setSubexpressionInfo(uint32_t subexpressionDivot, uint16_t subexpressionOffset)
        {
            ASSERT(subexpressionDivot >= divot());
            if ((subexpressionDivot - divot()) & ~0xFFFF) // Overflow means we can't do this safely, so just point at the primary divot
                return;
            m_subexpressionDivotOffset = subexpressionDivot - divot();
            m_subexpressionStartOffset = subexpressionOffset;
        }

    protected:
        uint16_t m_subexpressionDivotOffset;
        uint16_t m_subexpressionStartOffset;
    };

    class RegExpNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        RegExpNode(int, const Identifier& pattern, const Identifier& flags);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        const Identifier& m_pattern;
        const Identifier& m_flags;
    };

    class ThisNode : public ExpressionNode {
    public:
        ThisNode(int);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);
    };

    class ResolveNode : public ExpressionNode {
    public:
        ResolveNode(int, const Identifier&, int startOffset);

        const Identifier& identifier() const { return m_ident; }

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        virtual bool isPure(BytecodeGenerator&) const ;
        virtual bool isLocation() const { return true; }
        virtual bool isResolveNode() const { return true; }

        const Identifier& m_ident;
        int32_t m_startOffset;
    };

    class ElementNode : public ParserArenaFreeable {
    public:
        ElementNode(int elision, ExpressionNode*);
        ElementNode(ElementNode*, int elision, ExpressionNode*);

        int elision() const { return m_elision; }
        ExpressionNode* value() { return m_node; }
        ElementNode* next() { return m_next; }

    private:
        ElementNode* m_next;
        int m_elision;
        ExpressionNode* m_node;
    };

    class ArrayNode : public ExpressionNode {
    public:
        ArrayNode(int, int elision);
        ArrayNode(int, ElementNode*);
        ArrayNode(int, int elision, ElementNode*);

        ArgumentListNode* toArgumentList(JSGlobalData*, int) const;

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        virtual bool isSimpleArray() const ;

        ElementNode* m_element;
        int m_elision;
        bool m_optional;
    };

    class PropertyNode : public ParserArenaFreeable {
    public:
        enum Type { Constant = 1, Getter = 2, Setter = 4 };

        PropertyNode(JSGlobalData*, const Identifier&, ExpressionNode*, Type);
        PropertyNode(JSGlobalData*, double, ExpressionNode*, Type);

        const Identifier& name() const { return m_name; }
        Type type() const { return m_type; }

    private:
        friend class PropertyListNode;
        const Identifier& m_name;
        ExpressionNode* m_assign;
        Type m_type;
    };

    class PropertyListNode : public Node {
    public:
        PropertyListNode(int, PropertyNode*);
        PropertyListNode(int, PropertyNode*, PropertyListNode*);

        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

    private:
        PropertyNode* m_node;
        PropertyListNode* m_next;
    };

    class ObjectLiteralNode : public ExpressionNode {
    public:
        ObjectLiteralNode(int);
        ObjectLiteralNode(int, PropertyListNode*);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        PropertyListNode* m_list;
    };
    
    class BracketAccessorNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        BracketAccessorNode(int, ExpressionNode* base, ExpressionNode* subscript, bool subscriptHasAssignments);

        ExpressionNode* base() const { return m_base; }
        ExpressionNode* subscript() const { return m_subscript; }

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        virtual bool isLocation() const { return true; }
        virtual bool isBracketAccessorNode() const { return true; }

        ExpressionNode* m_base;
        ExpressionNode* m_subscript;
        bool m_subscriptHasAssignments;
    };

    class DotAccessorNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        DotAccessorNode(int, ExpressionNode* base, const Identifier&);

        ExpressionNode* base() const { return m_base; }
        const Identifier& identifier() const { return m_ident; }

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        virtual bool isLocation() const { return true; }
        virtual bool isDotAccessorNode() const { return true; }

        ExpressionNode* m_base;
        const Identifier& m_ident;
    };

    class ArgumentListNode : public Node {
    public:
        ArgumentListNode(int, ExpressionNode*);
        ArgumentListNode(int, ArgumentListNode*, ExpressionNode*);

        ArgumentListNode* m_next;
        ExpressionNode* m_expr;

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);
    };

    class ArgumentsNode : public ParserArenaFreeable {
    public:
        ArgumentsNode();
        ArgumentsNode(ArgumentListNode*);

        ArgumentListNode* m_listNode;
    };

    class NewExprNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        NewExprNode(int, ExpressionNode*);
        NewExprNode(int, ExpressionNode*, ArgumentsNode*);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_expr;
        ArgumentsNode* m_args;
    };

    class EvalFunctionCallNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        EvalFunctionCallNode(int, ArgumentsNode*, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ArgumentsNode* m_args;
    };

    class FunctionCallValueNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        FunctionCallValueNode(int, ExpressionNode*, ArgumentsNode*, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_expr;
        ArgumentsNode* m_args;
    };

    class FunctionCallResolveNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        FunctionCallResolveNode(int, const Identifier&, ArgumentsNode*, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        const Identifier& m_ident;
        ArgumentsNode* m_args;
        size_t m_index; // Used by LocalVarFunctionCallNode.
        size_t m_scopeDepth; // Used by ScopedVarFunctionCallNode and NonLocalVarFunctionCallNode
    };
    
    class FunctionCallBracketNode : public ExpressionNode, public ThrowableSubExpressionData {
    public:
        FunctionCallBracketNode(int, ExpressionNode* base, ExpressionNode* subscript, ArgumentsNode*, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_base;
        ExpressionNode* m_subscript;
        ArgumentsNode* m_args;
    };

    class FunctionCallDotNode : public ExpressionNode, public ThrowableSubExpressionData {
    public:
        FunctionCallDotNode(int, ExpressionNode* base, const Identifier&, ArgumentsNode*, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

    protected:
        ExpressionNode* m_base;
        const Identifier& m_ident;
        ArgumentsNode* m_args;
    };

    class CallFunctionCallDotNode : public FunctionCallDotNode {
    public:
        CallFunctionCallDotNode(int, ExpressionNode* base, const Identifier&, ArgumentsNode*, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);
    };
    
    class ApplyFunctionCallDotNode : public FunctionCallDotNode {
    public:
        ApplyFunctionCallDotNode(int, ExpressionNode* base, const Identifier&, ArgumentsNode*, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);
    };

    class PrePostResolveNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        PrePostResolveNode(int, const Identifier&, unsigned divot, unsigned startOffset, unsigned endOffset);

    protected:
        const Identifier& m_ident;
    };

    class PostfixResolveNode : public PrePostResolveNode {
    public:
        PostfixResolveNode(int, const Identifier&, Operator, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        Operator m_operator;
    };

    class PostfixBracketNode : public ExpressionNode, public ThrowableSubExpressionData {
    public:
        PostfixBracketNode(int, ExpressionNode* base, ExpressionNode* subscript, Operator, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_base;
        ExpressionNode* m_subscript;
        Operator m_operator;
    };

    class PostfixDotNode : public ExpressionNode, public ThrowableSubExpressionData {
    public:
        PostfixDotNode(int, ExpressionNode* base, const Identifier&, Operator, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_base;
        const Identifier& m_ident;
        Operator m_operator;
    };

    class PostfixErrorNode : public ExpressionNode, public ThrowableSubExpressionData {
    public:
        PostfixErrorNode(int, ExpressionNode*, Operator, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_expr;
        Operator m_operator;
    };

    class DeleteResolveNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        DeleteResolveNode(int, const Identifier&, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        const Identifier& m_ident;
    };

    class DeleteBracketNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        DeleteBracketNode(int, ExpressionNode* base, ExpressionNode* subscript, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_base;
        ExpressionNode* m_subscript;
    };

    class DeleteDotNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        DeleteDotNode(int, ExpressionNode* base, const Identifier&, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_base;
        const Identifier& m_ident;
    };

    class DeleteValueNode : public ExpressionNode {
    public:
        DeleteValueNode(int, ExpressionNode*);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_expr;
    };

    class VoidNode : public ExpressionNode {
    public:
        VoidNode(int, ExpressionNode*);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_expr;
    };

    class TypeOfResolveNode : public ExpressionNode {
    public:
        TypeOfResolveNode(int, const Identifier&);

        const Identifier& identifier() const { return m_ident; }

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        const Identifier& m_ident;
    };

    class TypeOfValueNode : public ExpressionNode {
    public:
        TypeOfValueNode(int, ExpressionNode*);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_expr;
    };

    class PrefixResolveNode : public PrePostResolveNode {
    public:
        PrefixResolveNode(int, const Identifier&, Operator, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        Operator m_operator;
    };

    class PrefixBracketNode : public ExpressionNode, public ThrowablePrefixedSubExpressionData {
    public:
        PrefixBracketNode(int, ExpressionNode* base, ExpressionNode* subscript, Operator, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_base;
        ExpressionNode* m_subscript;
        Operator m_operator;
    };

    class PrefixDotNode : public ExpressionNode, public ThrowablePrefixedSubExpressionData {
    public:
        PrefixDotNode(int, ExpressionNode* base, const Identifier&, Operator, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_base;
        const Identifier& m_ident;
        Operator m_operator;
    };

    class PrefixErrorNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        PrefixErrorNode(int, ExpressionNode*, Operator, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_expr;
        Operator m_operator;
    };

    class UnaryOpNode : public ExpressionNode {
    public:
        UnaryOpNode(int, ResultType, ExpressionNode*, OpcodeID);

    protected:
        ExpressionNode* expr() { return m_expr; }
        const ExpressionNode* expr() const { return m_expr; }

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        OpcodeID opcodeID() const { return m_opcodeID; }

        ExpressionNode* m_expr;
        OpcodeID m_opcodeID;
    };

    class UnaryPlusNode : public UnaryOpNode {
    public:
        UnaryPlusNode(int, ExpressionNode*);

    private:
        virtual ExpressionNode* stripUnaryPlus() { return expr(); }
    };

    class NegateNode : public UnaryOpNode {
    public:
        NegateNode(int, ExpressionNode*);
    };

    class BitwiseNotNode : public UnaryOpNode {
    public:
        BitwiseNotNode(int, ExpressionNode*);
    };

    class LogicalNotNode : public UnaryOpNode {
    public:
        LogicalNotNode(int, ExpressionNode*);
    private:
        void emitBytecodeInConditionContext(BytecodeGenerator&, Label* trueTarget, Label* falseTarget, bool fallThroughMeansTrue);
        virtual bool hasConditionContextCodegen() const { return expr()->hasConditionContextCodegen(); }
    };

    class BinaryOpNode : public ExpressionNode {
    public:
        BinaryOpNode(int, ExpressionNode* expr1, ExpressionNode* expr2, OpcodeID, bool rightHasAssignments);
        BinaryOpNode(int, ResultType, ExpressionNode* expr1, ExpressionNode* expr2, OpcodeID, bool rightHasAssignments);

        RegisterID* emitStrcat(BytecodeGenerator& generator, RegisterID* destination, RegisterID* lhs = 0, ReadModifyResolveNode* emitExpressionInfoForMe = 0);

        ExpressionNode* lhs() { return m_expr1; };
        ExpressionNode* rhs() { return m_expr2; };

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

    protected:
        OpcodeID opcodeID() const { return m_opcodeID; }

    protected:
        ExpressionNode* m_expr1;
        ExpressionNode* m_expr2;
    private:
        OpcodeID m_opcodeID;
    protected:
        bool m_rightHasAssignments;
    };

    class MultNode : public BinaryOpNode {
    public:
        MultNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    class DivNode : public BinaryOpNode {
    public:
        DivNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    class ModNode : public BinaryOpNode {
    public:
        ModNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    class AddNode : public BinaryOpNode {
    public:
        AddNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);

        virtual bool isAdd() const { return true; }
    };

    class SubNode : public BinaryOpNode {
    public:
        SubNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);

        virtual bool isSubtract() const { return true; }
    };

    class LeftShiftNode : public BinaryOpNode {
    public:
        LeftShiftNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    class RightShiftNode : public BinaryOpNode {
    public:
        RightShiftNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    class UnsignedRightShiftNode : public BinaryOpNode {
    public:
        UnsignedRightShiftNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    class LessNode : public BinaryOpNode {
    public:
        LessNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    class GreaterNode : public BinaryOpNode {
    public:
        GreaterNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    class LessEqNode : public BinaryOpNode {
    public:
        LessEqNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    class GreaterEqNode : public BinaryOpNode {
    public:
        GreaterEqNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    class ThrowableBinaryOpNode : public BinaryOpNode, public ThrowableExpressionData {
    public:
        ThrowableBinaryOpNode(int, ResultType, ExpressionNode* expr1, ExpressionNode* expr2, OpcodeID, bool rightHasAssignments);
        ThrowableBinaryOpNode(int, ExpressionNode* expr1, ExpressionNode* expr2, OpcodeID, bool rightHasAssignments);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);
    };
    
    class InstanceOfNode : public ThrowableBinaryOpNode {
    public:
        InstanceOfNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);
    };

    class InNode : public ThrowableBinaryOpNode {
    public:
        InNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    class EqualNode : public BinaryOpNode {
    public:
        EqualNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);
    };

    class NotEqualNode : public BinaryOpNode {
    public:
        NotEqualNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    class StrictEqualNode : public BinaryOpNode {
    public:
        StrictEqualNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);
    };

    class NotStrictEqualNode : public BinaryOpNode {
    public:
        NotStrictEqualNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    class BitAndNode : public BinaryOpNode {
    public:
        BitAndNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    class BitOrNode : public BinaryOpNode {
    public:
        BitOrNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    class BitXOrNode : public BinaryOpNode {
    public:
        BitXOrNode(int, ExpressionNode* expr1, ExpressionNode* expr2, bool rightHasAssignments);
    };

    // m_expr1 && m_expr2, m_expr1 || m_expr2
    class LogicalOpNode : public ExpressionNode {
    public:
        LogicalOpNode(int, ExpressionNode* expr1, ExpressionNode* expr2, LogicalOperator);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);
        void emitBytecodeInConditionContext(BytecodeGenerator&, Label* trueTarget, Label* falseTarget, bool fallThroughMeansTrue);
        virtual bool hasConditionContextCodegen() const { return true; }

        ExpressionNode* m_expr1;
        ExpressionNode* m_expr2;
        LogicalOperator m_operator;
    };

    // The ternary operator, "m_logical ? m_expr1 : m_expr2"
    class ConditionalNode : public ExpressionNode {
    public:
        ConditionalNode(int, ExpressionNode* logical, ExpressionNode* expr1, ExpressionNode* expr2);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_logical;
        ExpressionNode* m_expr1;
        ExpressionNode* m_expr2;
    };

    class ReadModifyResolveNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        ReadModifyResolveNode(int, const Identifier&, Operator, ExpressionNode*  right, bool rightHasAssignments, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        const Identifier& m_ident;
        ExpressionNode* m_right;
        size_t m_index; // Used by ReadModifyLocalVarNode.
        Operator m_operator;
        bool m_rightHasAssignments;
    };

    class AssignResolveNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        AssignResolveNode(int, const Identifier&, ExpressionNode* right, bool rightHasAssignments);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        const Identifier& m_ident;
        ExpressionNode* m_right;
        size_t m_index; // Used by ReadModifyLocalVarNode.
        bool m_rightHasAssignments;
    };

    class ReadModifyBracketNode : public ExpressionNode, public ThrowableSubExpressionData {
    public:
        ReadModifyBracketNode(int, ExpressionNode* base, ExpressionNode* subscript, Operator, ExpressionNode* right, bool subscriptHasAssignments, bool rightHasAssignments, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_base;
        ExpressionNode* m_subscript;
        ExpressionNode* m_right;
        Operator m_operator : 30;
        bool m_subscriptHasAssignments : 1;
        bool m_rightHasAssignments : 1;
    };

    class AssignBracketNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        AssignBracketNode(int, ExpressionNode* base, ExpressionNode* subscript, ExpressionNode* right, bool subscriptHasAssignments, bool rightHasAssignments, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_base;
        ExpressionNode* m_subscript;
        ExpressionNode* m_right;
        bool m_subscriptHasAssignments : 1;
        bool m_rightHasAssignments : 1;
    };

    class AssignDotNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        AssignDotNode(int, ExpressionNode* base, const Identifier&, ExpressionNode* right, bool rightHasAssignments, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_base;
        const Identifier& m_ident;
        ExpressionNode* m_right;
        bool m_rightHasAssignments;
    };

    class ReadModifyDotNode : public ExpressionNode, public ThrowableSubExpressionData {
    public:
        ReadModifyDotNode(int, ExpressionNode* base, const Identifier&, Operator, ExpressionNode* right, bool rightHasAssignments, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_base;
        const Identifier& m_ident;
        ExpressionNode* m_right;
        Operator m_operator : 31;
        bool m_rightHasAssignments : 1;
    };

    class AssignErrorNode : public ExpressionNode, public ThrowableExpressionData {
    public:
        AssignErrorNode(int, ExpressionNode* left, Operator, ExpressionNode* right, unsigned divot, unsigned startOffset, unsigned endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_left;
        Operator m_operator;
        ExpressionNode* m_right;
    };
    
    typedef Vector<ExpressionNode*, 8> ExpressionVector;

    class CommaNode : public ExpressionNode, public ParserArenaDeletable {
    public:
        CommaNode(int, ExpressionNode* expr1, ExpressionNode* expr2);

        using ParserArenaDeletable::operator new;

        void append(ExpressionNode* expr) { m_expressions.append(expr); }

    private:
        virtual bool isCommaNode() const { return true; }
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionVector m_expressions;
    };
    
    class ConstDeclNode : public ExpressionNode {
    public:
        ConstDeclNode(int, const Identifier&, ExpressionNode*);

        bool hasInitializer() const { return m_init; }
        const Identifier& ident() { return m_ident; }

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);
        virtual RegisterID* emitCodeSingle(BytecodeGenerator&);

        const Identifier& m_ident;

    public:
        ConstDeclNode* m_next;

    private:
        ExpressionNode* m_init;
    };

    class ConstStatementNode : public StatementNode {
    public:
        ConstStatementNode(int, ConstDeclNode* next);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ConstDeclNode* m_next;
    };

    class SourceElements : public ParserArenaDeletable {
    public:
        SourceElements();

        void append(StatementNode*);

        StatementNode* singleStatement() const;
        StatementNode* lastStatement() const;

        void emitBytecode(BytecodeGenerator&, RegisterID* destination);

    private:
        Vector<StatementNode*> m_statements;
    };

    class BlockNode : public StatementNode {
    public:
        BlockNode(int, SourceElements* = 0);

        StatementNode* singleStatement() const;
        StatementNode* lastStatement() const;

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        virtual bool isBlock() const { return true; }

        SourceElements* m_statements;
    };

    class EmptyStatementNode : public StatementNode {
    public:
        EmptyStatementNode(int);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        virtual bool isEmptyStatement() const { return true; }
    };
    
    class DebuggerStatementNode : public StatementNode {
    public:
        DebuggerStatementNode(int);
        
    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);
    };

    class ExprStatementNode : public StatementNode {
    public:
        ExprStatementNode(int, ExpressionNode*);

        ExpressionNode* expr() const { return m_expr; }

    private:
        virtual bool isExprStatement() const { return true; }

        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_expr;
    };

    class VarStatementNode : public StatementNode {
    public:
        VarStatementNode(int, ExpressionNode*);        

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_expr;
    };

    class IfNode : public StatementNode {
    public:
        IfNode(int, ExpressionNode* condition, StatementNode* ifBlock);

    protected:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_condition;
        StatementNode* m_ifBlock;
    };

    class IfElseNode : public IfNode {
    public:
        IfElseNode(int, ExpressionNode* condition, StatementNode* ifBlock, StatementNode* elseBlock);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        StatementNode* m_elseBlock;
    };

    class DoWhileNode : public StatementNode {
    public:
        DoWhileNode(int, StatementNode*, ExpressionNode*);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        StatementNode* m_statement;
        ExpressionNode* m_expr;
    };

    class WhileNode : public StatementNode {
    public:
        WhileNode(int, ExpressionNode*, StatementNode*);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_expr;
        StatementNode* m_statement;
    };

    class ForNode : public StatementNode {
    public:
        ForNode(int, ExpressionNode* expr1, ExpressionNode* expr2, ExpressionNode* expr3, StatementNode*, bool expr1WasVarDecl);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_expr1;
        ExpressionNode* m_expr2;
        ExpressionNode* m_expr3;
        StatementNode* m_statement;
        bool m_expr1WasVarDecl;
    };

    class ForInNode : public StatementNode, public ThrowableExpressionData {
    public:
        ForInNode(JSGlobalData*, int, ExpressionNode*, ExpressionNode*, StatementNode*);
        ForInNode(JSGlobalData*, int, const Identifier&, ExpressionNode*, ExpressionNode*, StatementNode*, int divot, int startOffset, int endOffset);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        const Identifier& m_ident;
        ExpressionNode* m_init;
        ExpressionNode* m_lexpr;
        ExpressionNode* m_expr;
        StatementNode* m_statement;
        bool m_identIsVarDecl;
    };

    class ContinueNode : public StatementNode, public ThrowableExpressionData {
    public:
        ContinueNode(JSGlobalData*, int);
        ContinueNode(int, const Identifier&);
        
    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        const Identifier& m_ident;
    };

    class BreakNode : public StatementNode, public ThrowableExpressionData {
    public:
        BreakNode(JSGlobalData*, int);
        BreakNode(int, const Identifier&);
        
    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        const Identifier& m_ident;
    };

    class ReturnNode : public StatementNode, public ThrowableExpressionData {
    public:
        ReturnNode(int, ExpressionNode* value);

        ExpressionNode* value() { return m_value; }

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        virtual bool isReturnNode() const { return true; }

        ExpressionNode* m_value;
    };

    class WithNode : public StatementNode {
    public:
        WithNode(int, ExpressionNode*, StatementNode*, uint32_t divot, uint32_t expressionLength);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_expr;
        StatementNode* m_statement;
        uint32_t m_divot;
        uint32_t m_expressionLength;
    };

    class LabelNode : public StatementNode, public ThrowableExpressionData {
    public:
        LabelNode(int, const Identifier& name, StatementNode*);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        const Identifier& m_name;
        StatementNode* m_statement;
    };

    class ThrowNode : public StatementNode, public ThrowableExpressionData {
    public:
        ThrowNode(int, ExpressionNode*);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_expr;
    };

    class TryNode : public StatementNode {
    public:
        TryNode(int, StatementNode* tryBlock, const Identifier& exceptionIdent, bool catchHasEval, StatementNode* catchBlock, StatementNode* finallyBlock);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        StatementNode* m_tryBlock;
        const Identifier& m_exceptionIdent;
        StatementNode* m_catchBlock;
        StatementNode* m_finallyBlock;
        bool m_catchHasEval;
    };

    class ParameterNode : public ParserArenaFreeable {
    public:
        ParameterNode(const Identifier&);
        ParameterNode(ParameterNode*, const Identifier&);

        const Identifier& ident() const { return m_ident; }
        ParameterNode* nextParam() const { return m_next; }

    private:
        const Identifier& m_ident;
        ParameterNode* m_next;
    };

    struct ScopeNodeData {
        WTF_MAKE_FAST_ALLOCATED;
    public:
        typedef DeclarationStacks::VarStack VarStack;
        typedef DeclarationStacks::FunctionStack FunctionStack;

        ScopeNodeData(ParserArena&, SourceElements*, VarStack*, FunctionStack*, IdentifierSet&, int numConstants);

        ParserArena m_arena;
        VarStack m_varStack;
        FunctionStack m_functionStack;
        int m_numConstants;
        SourceElements* m_statements;
        IdentifierSet m_capturedVariables;
    };

    class ScopeNode : public StatementNode, public ParserArenaRefCounted {
    public:
        typedef DeclarationStacks::VarStack VarStack;
        typedef DeclarationStacks::FunctionStack FunctionStack;

        ScopeNode(JSGlobalData*, int, bool inStrictContext);
        ScopeNode(JSGlobalData*, int, const SourceCode&, SourceElements*, VarStack*, FunctionStack*, IdentifierSet&, CodeFeatures, int numConstants);

        using ParserArenaRefCounted::operator new;

        ScopeNodeData* data() const { return m_data.get(); }
        void destroyData() { m_data.clear(); }

        const SourceCode& source() const { return m_source; }
        const UString& sourceURL() const { return m_source.provider()->url(); }
        intptr_t sourceID() const { return m_source.provider()->asID(); }

        void setFeatures(CodeFeatures features) { m_features = features; }
        CodeFeatures features() { return m_features; }

        bool usesEval() const { return m_features & EvalFeature; }
        bool usesArguments() const { return (m_features & ArgumentsFeature) && !(m_features & ShadowsArgumentsFeature); }
        bool isStrictMode() const { return m_features & StrictModeFeature; }
        void setUsesArguments() { m_features |= ArgumentsFeature; }
        bool usesThis() const { return m_features & ThisFeature; }
        bool needsActivationForMoreThanVariables() const { ASSERT(m_data); return m_features & (EvalFeature | WithFeature | CatchFeature); }
        bool needsActivation() const { ASSERT(m_data); return (hasCapturedVariables()) || (m_features & (EvalFeature | WithFeature | CatchFeature)); }
        bool hasCapturedVariables() const { return !!m_data->m_capturedVariables.size(); }
        size_t capturedVariableCount() const { return m_data->m_capturedVariables.size(); }
        bool captures(const Identifier& ident) { return m_data->m_capturedVariables.contains(ident.impl()); }

        VarStack& varStack() { ASSERT(m_data); return m_data->m_varStack; }
        FunctionStack& functionStack() { ASSERT(m_data); return m_data->m_functionStack; }

        int neededConstants()
        {
            ASSERT(m_data);
            // We may need 2 more constants than the count given by the parser,
            // because of the various uses of jsUndefined() and jsNull().
            return m_data->m_numConstants + 2;
        }

        StatementNode* singleStatement() const;

        void emitStatementsBytecode(BytecodeGenerator&, RegisterID* destination);

    protected:
        void setSource(const SourceCode& source) { m_source = source; }

    private:
        OwnPtr<ScopeNodeData> m_data;
        CodeFeatures m_features;
        SourceCode m_source;
    };

    class ProgramNode : public ScopeNode {
    public:
        static const bool isFunctionNode = false;
        static PassRefPtr<ProgramNode> create(JSGlobalData*, int, SourceElements*, VarStack*, FunctionStack*, IdentifierSet&, const SourceCode&, CodeFeatures, int numConstants);

        static const bool scopeIsFunction = false;

    private:
        ProgramNode(JSGlobalData*, int, SourceElements*, VarStack*, FunctionStack*, IdentifierSet&, const SourceCode&, CodeFeatures, int numConstants);

        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);
    };

    class EvalNode : public ScopeNode {
    public:
        static const bool isFunctionNode = false;
        static PassRefPtr<EvalNode> create(JSGlobalData*, int, SourceElements*, VarStack*, FunctionStack*, IdentifierSet&, const SourceCode&, CodeFeatures, int numConstants);

        static const bool scopeIsFunction = false;

    private:
        EvalNode(JSGlobalData*, int, SourceElements*, VarStack*, FunctionStack*, IdentifierSet&, const SourceCode&, CodeFeatures, int numConstants);

        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);
    };

    class FunctionParameters : public Vector<Identifier>, public RefCounted<FunctionParameters> {
        WTF_MAKE_FAST_ALLOCATED;
    public:
        static PassRefPtr<FunctionParameters> create(ParameterNode* firstParameter) { return adoptRef(new FunctionParameters(firstParameter)); }

    private:
        FunctionParameters(ParameterNode*);
    };

    class FunctionBodyNode : public ScopeNode {
    public:
        static const bool isFunctionNode = true;
        static FunctionBodyNode* create(JSGlobalData*, int, bool isStrictMode);
        static PassRefPtr<FunctionBodyNode> create(JSGlobalData*, int, SourceElements*, VarStack*, FunctionStack*, IdentifierSet&, const SourceCode&, CodeFeatures, int numConstants);

        FunctionParameters* parameters() const { return m_parameters.get(); }
        size_t parameterCount() const { return m_parameters->size(); }

        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        void finishParsing(const SourceCode&, ParameterNode*, const Identifier&);
        void finishParsing(PassRefPtr<FunctionParameters>, const Identifier&);
        
        const Identifier& ident() { return m_ident; }

        static const bool scopeIsFunction = true;

    private:
        FunctionBodyNode(JSGlobalData*, int, bool inStrictContext);
        FunctionBodyNode(JSGlobalData*, int, SourceElements*, VarStack*, FunctionStack*, IdentifierSet&, const SourceCode&, CodeFeatures, int numConstants);

        Identifier m_ident;
        RefPtr<FunctionParameters> m_parameters;
    };

    class FuncExprNode : public ExpressionNode {
    public:
        FuncExprNode(int, const Identifier&, FunctionBodyNode*, const SourceCode&, ParameterNode* = 0);

        FunctionBodyNode* body() { return m_body; }

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        virtual bool isFuncExprNode() const { return true; } 

        FunctionBodyNode* m_body;
    };

    class FuncDeclNode : public StatementNode {
    public:
        FuncDeclNode(int, const Identifier&, FunctionBodyNode*, const SourceCode&, ParameterNode* = 0);

        FunctionBodyNode* body() { return m_body; }

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        FunctionBodyNode* m_body;
    };

    class CaseClauseNode : public ParserArenaFreeable {
    public:
        CaseClauseNode(ExpressionNode*, SourceElements* = 0);

        ExpressionNode* expr() const { return m_expr; }

        void emitBytecode(BytecodeGenerator&, RegisterID* destination);

    private:
        ExpressionNode* m_expr;
        SourceElements* m_statements;
    };

    class ClauseListNode : public ParserArenaFreeable {
    public:
        ClauseListNode(CaseClauseNode*);
        ClauseListNode(ClauseListNode*, CaseClauseNode*);

        CaseClauseNode* getClause() const { return m_clause; }
        ClauseListNode* getNext() const { return m_next; }

    private:
        CaseClauseNode* m_clause;
        ClauseListNode* m_next;
    };

    class CaseBlockNode : public ParserArenaFreeable {
    public:
        CaseBlockNode(ClauseListNode* list1, CaseClauseNode* defaultClause, ClauseListNode* list2);

        RegisterID* emitBytecodeForBlock(BytecodeGenerator&, RegisterID* input, RegisterID* destination);

    private:
        SwitchInfo::SwitchType tryOptimizedSwitch(Vector<ExpressionNode*, 8>& literalVector, int32_t& min_num, int32_t& max_num);
        ClauseListNode* m_list1;
        CaseClauseNode* m_defaultClause;
        ClauseListNode* m_list2;
    };

    class SwitchNode : public StatementNode {
    public:
        SwitchNode(int, ExpressionNode*, CaseBlockNode*);

    private:
        virtual RegisterID* emitBytecode(BytecodeGenerator&, RegisterID* = 0);

        ExpressionNode* m_expr;
        CaseBlockNode* m_block;
    };

    struct ElementList {
        ElementNode* head;
        ElementNode* tail;
    };

    struct PropertyList {
        PropertyListNode* head;
        PropertyListNode* tail;
    };

    struct ArgumentList {
        ArgumentListNode* head;
        ArgumentListNode* tail;
    };

    struct ConstDeclList {
        ConstDeclNode* head;
        ConstDeclNode* tail;
    };

    struct ParameterList {
        ParameterNode* head;
        ParameterNode* tail;
    };

    struct ClauseList {
        ClauseListNode* head;
        ClauseListNode* tail;
    };

} // namespace JSC

#endif // Nodes_h
