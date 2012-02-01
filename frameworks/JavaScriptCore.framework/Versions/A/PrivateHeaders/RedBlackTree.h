/*
 * Copyright (C) 2010, 2011 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef RedBlackTree_h
#define RedBlackTree_h

#include <wtf/Assertions.h>
#include <wtf/Noncopyable.h>

namespace WTF {

// This implements a red-black tree with the following properties:
// - The allocation of nodes in the tree is entirely up to the user.
// - If you are in possession of a pointer to a node, you can delete
//   it from the tree. The tree will subsequently no longer have a
//   reference to this node.
// - The key type must implement operator< and ==.

template<class NodeType, typename KeyType>
class RedBlackTree {
    WTF_MAKE_NONCOPYABLE(RedBlackTree);
private:
    enum Color {
        Red = 1,
        Black
    };
    
public:
    class Node {
        friend class RedBlackTree;
        
    public:
        const NodeType* successor() const
        {
            const Node* x = this;
            if (x->right())
                return treeMinimum(x->right());
            const NodeType* y = x->parent();
            while (y && x == y->right()) {
                x = y;
                y = y->parent();
            }
            return y;
        }
        
        const NodeType* predecessor() const
        {
            const Node* x = this;
            if (x->left())
                return treeMaximum(x->left());
            const NodeType* y = x->parent();
            while (y && x == y->left()) {
                x = y;
                y = y->parent();
            }
            return y;
        }
        
        NodeType* successor()
        {
            return const_cast<NodeType*>(const_cast<const Node*>(this)->successor());
        }

        NodeType* predecessor()
        {
            return const_cast<NodeType*>(const_cast<const Node*>(this)->predecessor());
        }

    private:
        void reset()
        {
            m_left = 0;
            m_right = 0;
            m_parentAndRed = 1; // initialize to red
        }
        
        // NOTE: these methods should pack the parent and red into a single
        // word. But doing so appears to reveal a bug in the compiler.
        NodeType* parent() const
        {
            return reinterpret_cast<NodeType*>(m_parentAndRed & ~static_cast<uintptr_t>(1));
        }
        
        void setParent(NodeType* newParent)
        {
            m_parentAndRed = reinterpret_cast<uintptr_t>(newParent) | (m_parentAndRed & 1);
        }
        
        NodeType* left() const
        {
            return m_left;
        }
        
        void setLeft(NodeType* node)
        {
            m_left = node;
        }
        
        NodeType* right() const
        {
            return m_right;
        }
        
        void setRight(NodeType* node)
        {
            m_right = node;
        }
        
        Color color() const
        {
            if (m_parentAndRed & 1)
                return Red;
            return Black;
        }
        
        void setColor(Color value)
        {
            if (value == Red)
                m_parentAndRed |= 1;
            else
                m_parentAndRed &= ~static_cast<uintptr_t>(1);
        }
        
        NodeType* m_left;
        NodeType* m_right;
        uintptr_t m_parentAndRed;
    };

    RedBlackTree()
        : m_root(0)
    {
    }
    
    void insert(NodeType* x)
    {
        x->reset();
        treeInsert(x);
        x->setColor(Red);

        while (x != m_root && x->parent()->color() == Red) {
            if (x->parent() == x->parent()->parent()->left()) {
                NodeType* y = x->parent()->parent()->right();
                if (y && y->color() == Red) {
                    // Case 1
                    x->parent()->setColor(Black);
                    y->setColor(Black);
                    x->parent()->parent()->setColor(Red);
                    x = x->parent()->parent();
                } else {
                    if (x == x->parent()->right()) {
                        // Case 2
                        x = x->parent();
                        leftRotate(x);
                    }
                    // Case 3
                    x->parent()->setColor(Black);
                    x->parent()->parent()->setColor(Red);
                    rightRotate(x->parent()->parent());
                }
            } else {
                // Same as "then" clause with "right" and "left" exchanged.
                NodeType* y = x->parent()->parent()->left();
                if (y && y->color() == Red) {
                    // Case 1
                    x->parent()->setColor(Black);
                    y->setColor(Black);
                    x->parent()->parent()->setColor(Red);
                    x = x->parent()->parent();
                } else {
                    if (x == x->parent()->left()) {
                        // Case 2
                        x = x->parent();
                        rightRotate(x);
                    }
                    // Case 3
                    x->parent()->setColor(Black);
                    x->parent()->parent()->setColor(Red);
                    leftRotate(x->parent()->parent());
                }
            }
        }

        m_root->setColor(Black);
    }

    NodeType* remove(NodeType* z)
    {
        ASSERT(z);
        ASSERT(z->parent() || z == m_root);
        
        // Y is the node to be unlinked from the tree.
        NodeType* y;
        if (!z->left() || !z->right())
            y = z;
        else
            y = z->successor();

        // Y is guaranteed to be non-null at this point.
        NodeType* x;
        if (y->left())
            x = y->left();
        else
            x = y->right();

        // X is the child of y which might potentially replace y in
        // the tree. X might be null at this point.
        NodeType* xParent;
        if (x) {
            x->setParent(y->parent());
            xParent = x->parent();
        } else
            xParent = y->parent();
        if (!y->parent())
            m_root = x;
        else {
            if (y == y->parent()->left())
                y->parent()->setLeft(x);
            else
                y->parent()->setRight(x);
        }
            
        if (y != z) {
            if (y->color() == Black)
                removeFixup(x, xParent);
            
            y->setParent(z->parent());
            y->setColor(z->color());
            y->setLeft(z->left());
            y->setRight(z->right());
            
            if (z->left())
                z->left()->setParent(y);
            if (z->right())
                z->right()->setParent(y);
            if (z->parent()) {
                if (z->parent()->left() == z)
                    z->parent()->setLeft(y);
                else
                    z->parent()->setRight(y);
            } else {
                ASSERT(m_root == z);
                m_root = y;
            }
        } else if (y->color() == Black)
            removeFixup(x, xParent);

        return z;
    }
    
    NodeType* remove(const KeyType& key)
    {
        NodeType* result = findExact(key);
        if (!result)
            return 0;
        return remove(result);
    }
    
    NodeType* findExact(const KeyType& key) const
    {
        for (NodeType* current = m_root; current;) {
            if (current->key() == key)
                return current;
            if (key < current->key())
                current = current->left();
            else
                current = current->right();
        }
        return 0;
    }
    
    NodeType* findLeastGreaterThanOrEqual(const KeyType& key) const
    {
        NodeType* best = 0;
        for (NodeType* current = m_root; current;) {
            if (current->key() == key)
                return current;
            if (current->key() < key)
                current = current->right();
            else {
                best = current;
                current = current->left();
            }
        }
        return best;
    }
    
    NodeType* findGreatestLessThanOrEqual(const KeyType& key) const
    {
        NodeType* best = 0;
        for (NodeType* current = m_root; current;) {
            if (current->key() == key)
                return current;
            if (current->key() > key)
                current = current->left();
            else {
                best = current;
                current = current->right();
            }
        }
        return best;
    }
    
    NodeType* first() const
    {
        if (!m_root)
            return 0;
        return treeMinimum(m_root);
    }
    
    NodeType* last() const
    {
        if (!m_root)
            return 0;
        return treeMaximum(m_root);
    }
    
    // This is an O(n) operation.
    size_t size()
    {
        size_t result = 0;
        for (NodeType* current = first(); current; current = current->successor())
            result++;
        return result;
    }
    
    // This is an O(1) operation.
    bool isEmpty()
    {
        return !m_root;
    }
    
private:
    // Finds the minimum element in the sub-tree rooted at the given
    // node.
    static NodeType* treeMinimum(NodeType* x)
    {
        while (x->left())
            x = x->left();
        return x;
    }
    
    static NodeType* treeMaximum(NodeType* x)
    {
        while (x->right())
            x = x->right();
        return x;
    }

    static const NodeType* treeMinimum(const NodeType* x)
    {
        while (x->left())
            x = x->left();
        return x;
    }
    
    static const NodeType* treeMaximum(const NodeType* x)
    {
        while (x->right())
            x = x->right();
        return x;
    }

    void treeInsert(NodeType* z)
    {
        ASSERT(!z->left());
        ASSERT(!z->right());
        ASSERT(!z->parent());
        ASSERT(z->color() == Red);
        
        NodeType* y = 0;
        NodeType* x = m_root;
        while (x) {
            y = x;
            if (z->key() < x->key())
                x = x->left();
            else
                x = x->right();
        }
        z->setParent(y);
        if (!y)
            m_root = z;
        else {
            if (z->key() < y->key())
                y->setLeft(z);
            else
                y->setRight(z);
        }
    }

    //----------------------------------------------------------------------
    // Red-Black tree operations
    //

    // Left-rotates the subtree rooted at x.
    // Returns the new root of the subtree (x's right child).
    NodeType* leftRotate(NodeType* x)
    {
        // Set y.
        NodeType* y = x->right();

        // Turn y's left subtree into x's right subtree.
        x->setRight(y->left());
        if (y->left())
            y->left()->setParent(x);

        // Link x's parent to y.
        y->setParent(x->parent());
        if (!x->parent())
            m_root = y;
        else {
            if (x == x->parent()->left())
                x->parent()->setLeft(y);
            else
                x->parent()->setRight(y);
        }

        // Put x on y's left.
        y->setLeft(x);
        x->setParent(y);

        return y;
    }

    // Right-rotates the subtree rooted at y.
    // Returns the new root of the subtree (y's left child).
    NodeType* rightRotate(NodeType* y)
    {
        // Set x.
        NodeType* x = y->left();

        // Turn x's right subtree into y's left subtree.
        y->setLeft(x->right());
        if (x->right())
            x->right()->setParent(y);

        // Link y's parent to x.
        x->setParent(y->parent());
        if (!y->parent())
            m_root = x;
        else {
            if (y == y->parent()->left())
                y->parent()->setLeft(x);
            else
                y->parent()->setRight(x);
        }

        // Put y on x's right.
        x->setRight(y);
        y->setParent(x);

        return x;
    }

    // Restores the red-black property to the tree after splicing out
    // a node. Note that x may be null, which is why xParent must be
    // supplied.
    void removeFixup(NodeType* x, NodeType* xParent)
    {
        while (x != m_root && (!x || x->color() == Black)) {
            if (x == xParent->left()) {
                // Note: the text points out that w can not be null.
                // The reason is not obvious from simply looking at
                // the code; it comes about from the properties of the
                // red-black tree.
                NodeType* w = xParent->right();
                ASSERT(w); // x's sibling should not be null.
                if (w->color() == Red) {
                    // Case 1
                    w->setColor(Black);
                    xParent->setColor(Red);
                    leftRotate(xParent);
                    w = xParent->right();
                }
                if ((!w->left() || w->left()->color() == Black)
                    && (!w->right() || w->right()->color() == Black)) {
                    // Case 2
                    w->setColor(Red);
                    x = xParent;
                    xParent = x->parent();
                } else {
                    if (!w->right() || w->right()->color() == Black) {
                        // Case 3
                        w->left()->setColor(Black);
                        w->setColor(Red);
                        rightRotate(w);
                        w = xParent->right();
                    }
                    // Case 4
                    w->setColor(xParent->color());
                    xParent->setColor(Black);
                    if (w->right())
                        w->right()->setColor(Black);
                    leftRotate(xParent);
                    x = m_root;
                    xParent = x->parent();
                }
            } else {
                // Same as "then" clause with "right" and "left"
                // exchanged.

                // Note: the text points out that w can not be null.
                // The reason is not obvious from simply looking at
                // the code; it comes about from the properties of the
                // red-black tree.
                NodeType* w = xParent->left();
                ASSERT(w); // x's sibling should not be null.
                if (w->color() == Red) {
                    // Case 1
                    w->setColor(Black);
                    xParent->setColor(Red);
                    rightRotate(xParent);
                    w = xParent->left();
                }
                if ((!w->right() || w->right()->color() == Black)
                    && (!w->left() || w->left()->color() == Black)) {
                    // Case 2
                    w->setColor(Red);
                    x = xParent;
                    xParent = x->parent();
                } else {
                    if (!w->left() || w->left()->color() == Black) {
                        // Case 3
                        w->right()->setColor(Black);
                        w->setColor(Red);
                        leftRotate(w);
                        w = xParent->left();
                    }
                    // Case 4
                    w->setColor(xParent->color());
                    xParent->setColor(Black);
                    if (w->left())
                        w->left()->setColor(Black);
                    rightRotate(xParent);
                    x = m_root;
                    xParent = x->parent();
                }
            }
        }
        if (x)
            x->setColor(Black);
    }

    NodeType* m_root;
};

}

#endif

