/*
 * Copyright (C) 2008 Apple Inc. All rights reserved.
 *
 * Based on Abstract AVL Tree Template v1.5 by Walt Karas
 * <http://geocities.com/wkaras/gen_cpp/avl_tree.html>.
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

#ifndef AVL_TREE_H_
#define AVL_TREE_H_

#include "Assertions.h"
#include <wtf/FixedArray.h>

namespace WTF {

// Here is the reference class for BSet.
//
// class BSet
//   {
//   public:
//
//     class ANY_bitref
//       {
//       public:
//         operator bool ();
//         void operator = (bool b);
//       };
//
//     // Does not have to initialize bits.
//     BSet();
//
//     // Must return a valid value for index when 0 <= index < maxDepth
//     ANY_bitref operator [] (unsigned index);
//
//     // Set all bits to 1.
//     void set();
//
//     // Set all bits to 0.
//     void reset();
//   };

template<unsigned maxDepth>
class AVLTreeDefaultBSet {
public:
    bool& operator[](unsigned i) { ASSERT(i < maxDepth); return m_data[i]; }
    void set() { for (unsigned i = 0; i < maxDepth; ++i) m_data[i] = true; }
    void reset() { for (unsigned i = 0; i < maxDepth; ++i) m_data[i] = false; }

private:
    FixedArray<bool, maxDepth> m_data;
};

// How to determine maxDepth:
// d  Minimum number of nodes
// 2  2
// 3  4
// 4  7
// 5  12
// 6  20
// 7  33
// 8  54
// 9  88
// 10 143
// 11 232
// 12 376
// 13 609
// 14 986
// 15 1,596
// 16 2,583
// 17 4,180
// 18 6,764
// 19 10,945
// 20 17,710
// 21 28,656
// 22 46,367
// 23 75,024
// 24 121,392
// 25 196,417
// 26 317,810
// 27 514,228
// 28 832,039
// 29 1,346,268
// 30 2,178,308
// 31 3,524,577
// 32 5,702,886
// 33 9,227,464
// 34 14,930,351
// 35 24,157,816
// 36 39,088,168
// 37 63,245,985
// 38 102,334,154
// 39 165,580,140
// 40 267,914,295
// 41 433,494,436
// 42 701,408,732
// 43 1,134,903,169
// 44 1,836,311,902
// 45 2,971,215,072
//
// E.g., if, in a particular instantiation, the maximum number of nodes in a tree instance is 1,000,000, the maximum depth should be 28.
// You pick 28 because MN(28) is 832,039, which is less than or equal to 1,000,000, and MN(29) is 1,346,268, which is strictly greater than 1,000,000.

template <class Abstractor, unsigned maxDepth = 32, class BSet = AVLTreeDefaultBSet<maxDepth> >
class AVLTree {
public:

    typedef typename Abstractor::key key;
    typedef typename Abstractor::handle handle;
    typedef typename Abstractor::size size;

    enum SearchType {
        EQUAL = 1,
        LESS = 2,
        GREATER = 4,
        LESS_EQUAL = EQUAL | LESS,
        GREATER_EQUAL = EQUAL | GREATER
    };


    Abstractor& abstractor() { return abs; }

    inline handle insert(handle h);

    inline handle search(key k, SearchType st = EQUAL);
    inline handle search_least();
    inline handle search_greatest();

    inline handle remove(key k);

    inline handle subst(handle new_node);

    void purge() { abs.root = null(); }

    bool is_empty() { return abs.root == null(); }

    AVLTree() { abs.root = null(); }

    class Iterator {
    public:

        // Initialize depth to invalid value, to indicate iterator is
        // invalid.   (Depth is zero-base.)
        Iterator() { depth = ~0U; }

        void start_iter(AVLTree &tree, key k, SearchType st = EQUAL)
        {
            // Mask of high bit in an int.
            const int MASK_HIGH_BIT = (int) ~ ((~ (unsigned) 0) >> 1);

            // Save the tree that we're going to iterate through in a
            // member variable.
            tree_ = &tree;

            int cmp, target_cmp;
            handle h = tree_->abs.root;
            unsigned d = 0;

            depth = ~0U;

            if (h == null())
              // Tree is empty.
              return;

            if (st & LESS)
              // Key can be greater than key of starting node.
              target_cmp = 1;
            else if (st & GREATER)
              // Key can be less than key of starting node.
              target_cmp = -1;
            else
              // Key must be same as key of starting node.
              target_cmp = 0;

            for (;;) {
                cmp = cmp_k_n(k, h);
                if (cmp == 0) {
                    if (st & EQUAL) {
                        // Equal node was sought and found as starting node.
                        depth = d;
                        break;
                    }
                    cmp = -target_cmp;
                } else if (target_cmp != 0) {
                    if (!((cmp ^ target_cmp) & MASK_HIGH_BIT)) {
                        // cmp and target_cmp are both negative or both positive.
                        depth = d;
                    }
                }
                h = cmp < 0 ? get_lt(h) : get_gt(h);
                if (h == null())
                    break;
                branch[d] = cmp > 0;
                path_h[d++] = h;
            }
        }

        void start_iter_least(AVLTree &tree)
        {
            tree_ = &tree;

            handle h = tree_->abs.root;

            depth = ~0U;

            branch.reset();

            while (h != null()) {
                if (depth != ~0U)
                    path_h[depth] = h;
                depth++;
                h = get_lt(h);
            }
        }

        void start_iter_greatest(AVLTree &tree)
        {
            tree_ = &tree;

            handle h = tree_->abs.root;

            depth = ~0U;

            branch.set();

            while (h != null()) {
                if (depth != ~0U)
                    path_h[depth] = h;
                depth++;
                h = get_gt(h);
            }
        }

        handle operator*()
        {
            if (depth == ~0U)
                return null();

            return depth == 0 ? tree_->abs.root : path_h[depth - 1];
        }

        void operator++()
        {
            if (depth != ~0U) {
                handle h = get_gt(**this);
                if (h == null()) {
                    do {
                        if (depth == 0) {
                            depth = ~0U;
                            break;
                        }
                        depth--;
                    } while (branch[depth]);
                } else {
                    branch[depth] = true;
                    path_h[depth++] = h;
                    for (;;) {
                        h = get_lt(h);
                        if (h == null())
                            break;
                        branch[depth] = false;
                        path_h[depth++] = h;
                    }
                }
            }
        }

        void operator--()
        {
            if (depth != ~0U) {
                handle h = get_lt(**this);
                if (h == null())
                    do {
                        if (depth == 0) {
                            depth = ~0U;
                            break;
                        }
                        depth--;
                    } while (!branch[depth]);
                else {
                    branch[depth] = false;
                    path_h[depth++] = h;
                    for (;;) {
                        h = get_gt(h);
                        if (h == null())
                            break;
                        branch[depth] = true;
                        path_h[depth++] = h;
                    }
                }
            }
        }

        void operator++(int) { ++(*this); }
        void operator--(int) { --(*this); }

    protected:

        // Tree being iterated over.
        AVLTree *tree_;

        // Records a path into the tree.  If branch[n] is true, indicates
        // take greater branch from the nth node in the path, otherwise
        // take the less branch.  branch[0] gives branch from root, and
        // so on.
        BSet branch;

        // Zero-based depth of path into tree.
        unsigned depth;

        // Handles of nodes in path from root to current node (returned by *).
        handle path_h[maxDepth - 1];

        int cmp_k_n(key k, handle h) { return tree_->abs.compare_key_node(k, h); }
        int cmp_n_n(handle h1, handle h2) { return tree_->abs.compare_node_node(h1, h2); }
        handle get_lt(handle h) { return tree_->abs.get_less(h); }
        handle get_gt(handle h) { return tree_->abs.get_greater(h); }
        handle null() { return tree_->abs.null(); }
    };

    template<typename fwd_iter>
    bool build(fwd_iter p, size num_nodes)
    {
        if (num_nodes == 0) {
            abs.root = null();
            return true;
        }

        // Gives path to subtree being built.  If branch[N] is false, branch
        // less from the node at depth N, if true branch greater.
        BSet branch;

        // If rem[N] is true, then for the current subtree at depth N, it's
        // greater subtree has one more node than it's less subtree.
        BSet rem;

            // Depth of root node of current subtree.
        unsigned depth = 0;

            // Number of nodes in current subtree.
        size num_sub = num_nodes;

        // The algorithm relies on a stack of nodes whose less subtree has
        // been built, but whose right subtree has not yet been built.  The
        // stack is implemented as linked list.  The nodes are linked
        // together by having the "greater" handle of a node set to the
        // next node in the list.  "less_parent" is the handle of the first
        // node in the list.
        handle less_parent = null();

        // h is root of current subtree, child is one of its children.
        handle h, child;

        for (;;) {
            while (num_sub > 2) {
                // Subtract one for root of subtree.
                num_sub--;
                rem[depth] = !!(num_sub & 1);
                branch[depth++] = false;
                num_sub >>= 1;
            }

            if (num_sub == 2) {
                // Build a subtree with two nodes, slanting to greater.
                // I arbitrarily chose to always have the extra node in the
                // greater subtree when there is an odd number of nodes to
                // split between the two subtrees.

                h = *p;
                p++;
                child = *p;
                p++;
                set_lt(child, null());
                set_gt(child, null());
                set_bf(child, 0);
                set_gt(h, child);
                set_lt(h, null());
                set_bf(h, 1);
            } else { // num_sub == 1
                // Build a subtree with one node.

                h = *p;
                p++;
                set_lt(h, null());
                set_gt(h, null());
                set_bf(h, 0);
            }

            while (depth) {
                depth--;
                if (!branch[depth])
                    // We've completed a less subtree.
                    break;

                // We've completed a greater subtree, so attach it to
                // its parent (that is less than it).  We pop the parent
                // off the stack of less parents.
                child = h;
                h = less_parent;
                less_parent = get_gt(h);
                set_gt(h, child);
                // num_sub = 2 * (num_sub - rem[depth]) + rem[depth] + 1
                num_sub <<= 1;
                num_sub += 1 - rem[depth];
                if (num_sub & (num_sub - 1))
                    // num_sub is not a power of 2
                    set_bf(h, 0);
                else
                    // num_sub is a power of 2
                    set_bf(h, 1);
            }

            if (num_sub == num_nodes)
                // We've completed the full tree.
                break;

            // The subtree we've completed is the less subtree of the
            // next node in the sequence.

            child = h;
            h = *p;
            p++;
            set_lt(h, child);

            // Put h into stack of less parents.
            set_gt(h, less_parent);
            less_parent = h;

            // Proceed to creating greater than subtree of h.
            branch[depth] = true;
            num_sub += rem[depth++];

        } // end for (;;)

        abs.root = h;

        return true;
    }

protected:

    friend class Iterator;

    // Create a class whose sole purpose is to take advantage of
    // the "empty member" optimization.
    struct abs_plus_root : public Abstractor {
        // The handle of the root element in the AVL tree.
        handle root;
    };

    abs_plus_root abs;


    handle get_lt(handle h) { return abs.get_less(h); }
    void set_lt(handle h, handle lh) { abs.set_less(h, lh); }

    handle get_gt(handle h) { return abs.get_greater(h); }
    void set_gt(handle h, handle gh) { abs.set_greater(h, gh); }

    int get_bf(handle h) { return abs.get_balance_factor(h); }
    void set_bf(handle h, int bf) { abs.set_balance_factor(h, bf); }

    int cmp_k_n(key k, handle h) { return abs.compare_key_node(k, h); }
    int cmp_n_n(handle h1, handle h2) { return abs.compare_node_node(h1, h2); }

    handle null() { return abs.null(); }

private:

    // Balances subtree, returns handle of root node of subtree
    // after balancing.
    handle balance(handle bal_h)
    {
        handle deep_h;

        // Either the "greater than" or the "less than" subtree of
        // this node has to be 2 levels deeper (or else it wouldn't
        // need balancing).

        if (get_bf(bal_h) > 0) {
            // "Greater than" subtree is deeper.

            deep_h = get_gt(bal_h);

            if (get_bf(deep_h) < 0) {
                handle old_h = bal_h;
                bal_h = get_lt(deep_h);

                set_gt(old_h, get_lt(bal_h));
                set_lt(deep_h, get_gt(bal_h));
                set_lt(bal_h, old_h);
                set_gt(bal_h, deep_h);

                int bf = get_bf(bal_h);
                if (bf != 0) {
                    if (bf > 0) {
                        set_bf(old_h, -1);
                        set_bf(deep_h, 0);
                    } else {
                        set_bf(deep_h, 1);
                        set_bf(old_h, 0);
                    }
                    set_bf(bal_h, 0);
                } else {
                    set_bf(old_h, 0);
                    set_bf(deep_h, 0);
                }
            } else {
                set_gt(bal_h, get_lt(deep_h));
                set_lt(deep_h, bal_h);
                if (get_bf(deep_h) == 0) {
                    set_bf(deep_h, -1);
                    set_bf(bal_h, 1);
                } else {
                    set_bf(deep_h, 0);
                    set_bf(bal_h, 0);
                }
                bal_h = deep_h;
            }
        } else {
            // "Less than" subtree is deeper.

            deep_h = get_lt(bal_h);

            if (get_bf(deep_h) > 0) {
                handle old_h = bal_h;
                bal_h = get_gt(deep_h);
                set_lt(old_h, get_gt(bal_h));
                set_gt(deep_h, get_lt(bal_h));
                set_gt(bal_h, old_h);
                set_lt(bal_h, deep_h);

                int bf = get_bf(bal_h);
                if (bf != 0) {
                    if (bf < 0) {
                        set_bf(old_h, 1);
                        set_bf(deep_h, 0);
                    } else {
                        set_bf(deep_h, -1);
                        set_bf(old_h, 0);
                    }
                    set_bf(bal_h, 0);
                } else {
                    set_bf(old_h, 0);
                    set_bf(deep_h, 0);
                }
            } else {
                set_lt(bal_h, get_gt(deep_h));
                set_gt(deep_h, bal_h);
                if (get_bf(deep_h) == 0) {
                    set_bf(deep_h, 1);
                    set_bf(bal_h, -1);
                } else {
                    set_bf(deep_h, 0);
                    set_bf(bal_h, 0);
                }
                bal_h = deep_h;
            }
        }

        return bal_h;
    }

};

template <class Abstractor, unsigned maxDepth, class BSet>
inline typename AVLTree<Abstractor, maxDepth, BSet>::handle
AVLTree<Abstractor, maxDepth, BSet>::insert(handle h)
{
    set_lt(h, null());
    set_gt(h, null());
    set_bf(h, 0);

    if (abs.root == null())
        abs.root = h;
    else {
        // Last unbalanced node encountered in search for insertion point.
        handle unbal = null();
        // Parent of last unbalanced node.
        handle parent_unbal = null();
        // Balance factor of last unbalanced node.
        int unbal_bf;

        // Zero-based depth in tree.
        unsigned depth = 0, unbal_depth = 0;

        // Records a path into the tree.  If branch[n] is true, indicates
        // take greater branch from the nth node in the path, otherwise
        // take the less branch.  branch[0] gives branch from root, and
        // so on.
        BSet branch;

        handle hh = abs.root;
        handle parent = null();
        int cmp;

        do {
            if (get_bf(hh) != 0) {
                unbal = hh;
                parent_unbal = parent;
                unbal_depth = depth;
            }
            cmp = cmp_n_n(h, hh);
            if (cmp == 0)
                // Duplicate key.
                return hh;
            parent = hh;
            hh = cmp < 0 ? get_lt(hh) : get_gt(hh);
            branch[depth++] = cmp > 0;
        } while (hh != null());

        //  Add node to insert as leaf of tree.
        if (cmp < 0)
            set_lt(parent, h);
        else
            set_gt(parent, h);

        depth = unbal_depth;

        if (unbal == null())
            hh = abs.root;
        else {
            cmp = branch[depth++] ? 1 : -1;
            unbal_bf = get_bf(unbal);
            if (cmp < 0)
                unbal_bf--;
            else  // cmp > 0
                unbal_bf++;
            hh = cmp < 0 ? get_lt(unbal) : get_gt(unbal);
            if ((unbal_bf != -2) && (unbal_bf != 2)) {
                // No rebalancing of tree is necessary.
                set_bf(unbal, unbal_bf);
                unbal = null();
            }
        }

        if (hh != null())
            while (h != hh) {
                cmp = branch[depth++] ? 1 : -1;
                if (cmp < 0) {
                    set_bf(hh, -1);
                    hh = get_lt(hh);
                } else { // cmp > 0
                    set_bf(hh, 1);
                    hh = get_gt(hh);
                }
            }

        if (unbal != null()) {
            unbal = balance(unbal);
            if (parent_unbal == null())
                abs.root = unbal;
            else {
                depth = unbal_depth - 1;
                cmp = branch[depth] ? 1 : -1;
                if (cmp < 0)
                    set_lt(parent_unbal, unbal);
                else  // cmp > 0
                    set_gt(parent_unbal, unbal);
            }
        }
    }

    return h;
}

template <class Abstractor, unsigned maxDepth, class BSet>
inline typename AVLTree<Abstractor, maxDepth, BSet>::handle
AVLTree<Abstractor, maxDepth, BSet>::search(key k, typename AVLTree<Abstractor, maxDepth, BSet>::SearchType st)
{
    const int MASK_HIGH_BIT = (int) ~ ((~ (unsigned) 0) >> 1);

    int cmp, target_cmp;
    handle match_h = null();
    handle h = abs.root;

    if (st & LESS)
        target_cmp = 1;
    else if (st & GREATER)
        target_cmp = -1;
    else
        target_cmp = 0;

    while (h != null()) {
        cmp = cmp_k_n(k, h);
        if (cmp == 0) {
            if (st & EQUAL) {
                match_h = h;
                break;
            }
            cmp = -target_cmp;
        } else if (target_cmp != 0)
            if (!((cmp ^ target_cmp) & MASK_HIGH_BIT))
                // cmp and target_cmp are both positive or both negative.
                match_h = h;
        h = cmp < 0 ? get_lt(h) : get_gt(h);
    }

    return match_h;
}

template <class Abstractor, unsigned maxDepth, class BSet>
inline typename AVLTree<Abstractor, maxDepth, BSet>::handle
AVLTree<Abstractor, maxDepth, BSet>::search_least()
{
    handle h = abs.root, parent = null();

    while (h != null()) {
        parent = h;
        h = get_lt(h);
    }

    return parent;
}

template <class Abstractor, unsigned maxDepth, class BSet>
inline typename AVLTree<Abstractor, maxDepth, BSet>::handle
AVLTree<Abstractor, maxDepth, BSet>::search_greatest()
{
    handle h = abs.root, parent = null();

    while (h != null()) {
        parent = h;
        h = get_gt(h);
    }

    return parent;
}

template <class Abstractor, unsigned maxDepth, class BSet>
inline typename AVLTree<Abstractor, maxDepth, BSet>::handle
AVLTree<Abstractor, maxDepth, BSet>::remove(key k)
{
    // Zero-based depth in tree.
    unsigned depth = 0, rm_depth;

    // Records a path into the tree.  If branch[n] is true, indicates
    // take greater branch from the nth node in the path, otherwise
    // take the less branch.  branch[0] gives branch from root, and
    // so on.
    BSet branch;

    handle h = abs.root;
    handle parent = null(), child;
    int cmp, cmp_shortened_sub_with_path = 0;

    for (;;) {
        if (h == null())
            // No node in tree with given key.
            return null();
        cmp = cmp_k_n(k, h);
        if (cmp == 0)
            // Found node to remove.
            break;
        parent = h;
        h = cmp < 0 ? get_lt(h) : get_gt(h);
        branch[depth++] = cmp > 0;
        cmp_shortened_sub_with_path = cmp;
    }
    handle rm = h;
    handle parent_rm = parent;
    rm_depth = depth;

    // If the node to remove is not a leaf node, we need to get a
    // leaf node, or a node with a single leaf as its child, to put
    // in the place of the node to remove.  We will get the greatest
    // node in the less subtree (of the node to remove), or the least
    // node in the greater subtree.  We take the leaf node from the
    // deeper subtree, if there is one.

    if (get_bf(h) < 0) {
        child = get_lt(h);
        branch[depth] = false;
        cmp = -1;
    } else {
        child = get_gt(h);
        branch[depth] = true;
        cmp = 1;
    }
    depth++;

    if (child != null()) {
        cmp = -cmp;
        do {
            parent = h;
            h = child;
            if (cmp < 0) {
                child = get_lt(h);
                branch[depth] = false;
            } else {
                child = get_gt(h);
                branch[depth] = true;
            }
            depth++;
        } while (child != null());

        if (parent == rm)
            // Only went through do loop once.  Deleted node will be replaced
            // in the tree structure by one of its immediate children.
            cmp_shortened_sub_with_path = -cmp;
        else
            cmp_shortened_sub_with_path = cmp;

        // Get the handle of the opposite child, which may not be null.
        child = cmp > 0 ? get_lt(h) : get_gt(h);
    }

    if (parent == null())
        // There were only 1 or 2 nodes in this tree.
        abs.root = child;
    else if (cmp_shortened_sub_with_path < 0)
        set_lt(parent, child);
    else
        set_gt(parent, child);

    // "path" is the parent of the subtree being eliminated or reduced
    // from a depth of 2 to 1.  If "path" is the node to be removed, we
    // set path to the node we're about to poke into the position of the
    // node to be removed.
    handle path = parent == rm ? h : parent;

    if (h != rm) {
        // Poke in the replacement for the node to be removed.
        set_lt(h, get_lt(rm));
        set_gt(h, get_gt(rm));
        set_bf(h, get_bf(rm));
        if (parent_rm == null())
            abs.root = h;
        else {
            depth = rm_depth - 1;
            if (branch[depth])
                set_gt(parent_rm, h);
            else
                set_lt(parent_rm, h);
        }
    }

    if (path != null()) {
        // Create a temporary linked list from the parent of the path node
        // to the root node.
        h = abs.root;
        parent = null();
        depth = 0;
        while (h != path) {
            if (branch[depth++]) {
                child = get_gt(h);
                set_gt(h, parent);
            } else {
                child = get_lt(h);
                set_lt(h, parent);
            }
            parent = h;
            h = child;
        }

        // Climb from the path node to the root node using the linked
        // list, restoring the tree structure and rebalancing as necessary.
        bool reduced_depth = true;
        int bf;
        cmp = cmp_shortened_sub_with_path;
        for (;;) {
            if (reduced_depth) {
                bf = get_bf(h);
                if (cmp < 0)
                    bf++;
                else  // cmp > 0
                    bf--;
                if ((bf == -2) || (bf == 2)) {
                    h = balance(h);
                    bf = get_bf(h);
                } else
                    set_bf(h, bf);
                reduced_depth = (bf == 0);
            }
            if (parent == null())
                break;
            child = h;
            h = parent;
            cmp = branch[--depth] ? 1 : -1;
            if (cmp < 0)    {
                parent = get_lt(h);
                set_lt(h, child);
            } else {
                parent = get_gt(h);
                set_gt(h, child);
            }
        }
        abs.root = h;
    }

    return rm;
}

template <class Abstractor, unsigned maxDepth, class BSet>
inline typename AVLTree<Abstractor, maxDepth, BSet>::handle
AVLTree<Abstractor, maxDepth, BSet>::subst(handle new_node)
{
    handle h = abs.root;
    handle parent = null();
    int cmp, last_cmp;

    /* Search for node already in tree with same key. */
    for (;;) {
        if (h == null())
            /* No node in tree with same key as new node. */
            return null();
        cmp = cmp_n_n(new_node, h);
        if (cmp == 0)
            /* Found the node to substitute new one for. */
            break;
        last_cmp = cmp;
        parent = h;
        h = cmp < 0 ? get_lt(h) : get_gt(h);
    }

    /* Copy tree housekeeping fields from node in tree to new node. */
    set_lt(new_node, get_lt(h));
    set_gt(new_node, get_gt(h));
    set_bf(new_node, get_bf(h));

    if (parent == null())
        /* New node is also new root. */
        abs.root = new_node;
    else {
        /* Make parent point to new node. */
        if (last_cmp < 0)
            set_lt(parent, new_node);
        else
            set_gt(parent, new_node);
    }

    return h;
}

}

#endif
