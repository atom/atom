/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_tree_h__
#define INCLUDE_git_tree_h__

#include "common.h"
#include "types.h"
#include "oid.h"
#include "object.h"

/**
 * @file git2/tree.h
 * @brief Git tree parsing, loading routines
 * @defgroup git_tree Git tree parsing, loading routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Lookup a tree object from the repository.
 *
 * @param tree pointer to the looked up tree
 * @param repo the repo to use when locating the tree.
 * @param id identity of the tree to locate.
 * @return 0 or an error code
 */
GIT_INLINE(int) git_tree_lookup(git_tree **tree, git_repository *repo, const git_oid *id)
{
	return git_object_lookup((git_object **)tree, repo, id, GIT_OBJ_TREE);
}

/**
 * Lookup a tree object from the repository,
 * given a prefix of its identifier (short id).
 *
 * @see git_object_lookup_prefix
 *
 * @param tree pointer to the looked up tree
 * @param repo the repo to use when locating the tree.
 * @param id identity of the tree to locate.
 * @param len the length of the short identifier
 * @return 0 or an error code
 */
GIT_INLINE(int) git_tree_lookup_prefix(git_tree **tree, git_repository *repo, const git_oid *id, unsigned int len)
{
	return git_object_lookup_prefix((git_object **)tree, repo, id, len, GIT_OBJ_TREE);
}

/**
 * Close an open tree
 *
 * This is a wrapper around git_object_free()
 *
 * IMPORTANT:
 * It *is* necessary to call this method when you stop
 * using a tree. Failure to do so will cause a memory leak.
 *
 * @param tree the tree to close
 */

GIT_INLINE(void) git_tree_free(git_tree *tree)
{
	git_object_free((git_object *) tree);
}


/**
 * Get the id of a tree.
 *
 * @param tree a previously loaded tree.
 * @return object identity for the tree.
 */
GIT_EXTERN(const git_oid *) git_tree_id(git_tree *tree);

/**
 * Get the number of entries listed in a tree
 *
 * @param tree a previously loaded tree.
 * @return the number of entries in the tree
 */
GIT_EXTERN(unsigned int) git_tree_entrycount(git_tree *tree);

/**
 * Lookup a tree entry by its filename
 *
 * @param tree a previously loaded tree.
 * @param filename the filename of the desired entry
 * @return the tree entry; NULL if not found
 */
GIT_EXTERN(const git_tree_entry *) git_tree_entry_byname(git_tree *tree, const char *filename);

/**
 * Lookup a tree entry by its position in the tree
 *
 * @param tree a previously loaded tree.
 * @param idx the position in the entry list
 * @return the tree entry; NULL if not found
 */
GIT_EXTERN(const git_tree_entry *) git_tree_entry_byindex(git_tree *tree, unsigned int idx);

/**
 * Get the UNIX file attributes of a tree entry
 *
 * @param entry a tree entry
 * @return attributes as an integer
 */
GIT_EXTERN(unsigned int) git_tree_entry_attributes(const git_tree_entry *entry);

/**
 * Get the filename of a tree entry
 *
 * @param entry a tree entry
 * @return the name of the file
 */
GIT_EXTERN(const char *) git_tree_entry_name(const git_tree_entry *entry);

/**
 * Get the id of the object pointed by the entry
 *
 * @param entry a tree entry
 * @return the oid of the object
 */
GIT_EXTERN(const git_oid *) git_tree_entry_id(const git_tree_entry *entry);

/**
 * Get the type of the object pointed by the entry
 *
 * @param entry a tree entry
 * @return the type of the pointed object
 */
GIT_EXTERN(git_otype) git_tree_entry_type(const git_tree_entry *entry);

/**
 * Convert a tree entry to the git_object it points too.
 *
 * @param object pointer to the converted object
 * @param repo repository where to lookup the pointed object
 * @param entry a tree entry
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_tree_entry_to_object(git_object **object_out, git_repository *repo, const git_tree_entry *entry);

/**
 * Write a tree to the ODB from the index file
 *
 * This method will scan the index and write a representation
 * of its current state back to disk; it recursively creates
 * tree objects for each of the subtrees stored in the index,
 * but only returns the OID of the root tree. This is the OID
 * that can be used e.g. to create a commit.
 *
 * The index instance cannot be bare, and needs to be associated
 * to an existing repository.
 *
 * @param oid Pointer where to store the written tree
 * @param index Index to write
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_tree_create_fromindex(git_oid *oid, git_index *index);

/**
 * Create a new tree builder.
 *
 * The tree builder can be used to create or modify
 * trees in memory and write them as tree objects to the
 * database.
 *
 * If the `source` parameter is not NULL, the tree builder
 * will be initialized with the entries of the given tree.
 *
 * If the `source` parameter is NULL, the tree builder will
 * have no entries and will have to be filled manually.
 *
 * @param builder_p Pointer where to store the tree builder
 * @param source Source tree to initialize the builder (optional)
 * @return 0 on sucess; error code otherwise
 */
GIT_EXTERN(int) git_treebuilder_create(git_treebuilder **builder_p, const git_tree *source);

/**
 * Clear all the entires in the builder
 *
 * @param bld Builder to clear
 */
GIT_EXTERN(void) git_treebuilder_clear(git_treebuilder *bld);

/**
 * Free a tree builder
 *
 * This will clear all the entries and free to builder.
 * Failing to free the builder after you're done using it
 * will result in a memory leak
 *
 * @param bld Builder to free
 */
GIT_EXTERN(void) git_treebuilder_free(git_treebuilder *bld);

/**
 * Get an entry from the builder from its filename
 *
 * The returned entry is owned by the builder and should
 * not be freed manually.
 *
 * @param bld Tree builder
 * @param filename Name of the entry
 * @return pointer to the entry; NULL if not found
 */
GIT_EXTERN(const git_tree_entry *) git_treebuilder_get(git_treebuilder *bld, const char *filename);

/**
 * Add or update an entry to the builder
 *
 * Insert a new entry for `filename` in the builder with the
 * given attributes.
 *
 * if an entry named `filename` already exists, its attributes
 * will be updated with the given ones.
 *
 * The optional pointer `entry_out` can be used to retrieve a
 * pointer to the newly created/updated entry.
 *
 * @param entry_out Pointer to store the entry (optional)
 * @param bld Tree builder
 * @param filename Filename of the entry
 * @param id SHA1 oid of the entry
 * @param attributes Folder attributes of the entry
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_treebuilder_insert(git_tree_entry **entry_out, git_treebuilder *bld, const char *filename, const git_oid *id, unsigned int attributes);

/**
 * Remove an entry from the builder by its filename
 *
 * @param bld Tree builder
 * @param filename Filename of the entry to remove
 */
GIT_EXTERN(int) git_treebuilder_remove(git_treebuilder *bld, const char *filename);

/**
 * Filter the entries in the tree
 *
 * The `filter` callback will be called for each entry
 * in the tree with a pointer to the entry and the
 * provided `payload`: if the callback returns 1, the
 * entry will be filtered (removed from the builder).
 *
 * @param bld Tree builder
 * @param filter Callback to filter entries
 */
GIT_EXTERN(void) git_treebuilder_filter(git_treebuilder *bld, int (*filter)(const git_tree_entry *, void *), void *payload);

/**
 * Write the contents of the tree builder as a tree object
 *
 * The tree builder will be written to the given `repo`, and
 * it's identifying SHA1 hash will be stored in the `oid`
 * pointer.
 *
 * @param oid Pointer where to store the written OID
 * @param repo Repository where to store the object
 * @param bld Tree builder to write
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_treebuilder_write(git_oid *oid, git_repository *repo, git_treebuilder *bld);

/**
 * Retrieve a subtree contained in a tree, given its
 * relative path.
 *
 * The returned tree is owned by the repository and
 * should be closed with the `git_object_free` method.
 *
 * @param subtree Pointer where to store the subtree
 * @param root A previously loaded tree which will be the root of the relative path
 * @param subtree_path Path to the contained subtree
 * @return 0 on success; GIT_ENOTFOUND if the path does not lead to a subtree
 */
GIT_EXTERN(int) git_tree_get_subtree(git_tree **subtree, git_tree *root, const char *subtree_path);

/** Callback for the tree traversal method */
typedef int (*git_treewalk_cb)(const char *root, git_tree_entry *entry, void *payload);

/** Tree traversal modes */
enum git_treewalk_mode {
	GIT_TREEWALK_PRE = 0, /* Pre-order */
	GIT_TREEWALK_POST = 1, /* Post-order */
};

/**
 * Traverse the entries in a tree and its subtrees in
 * post or pre order
 *
 * The entries will be traversed in the specified order,
 * children subtrees will be automatically loaded as required,
 * and the `callback` will be called once per entry with
 * the current (relative) root for the entry and the entry
 * data itself.
 *
 * If the callback returns a negative value, the passed entry
 * will be skiped on the traversal.
 *
 * @param tree The tree to walk
 * @param callback Function to call on each tree entry
 * @param mode Traversal mode (pre or post-order)
 * @param payload Opaque pointer to be passed on each callback
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_tree_walk(git_tree *tree, git_treewalk_cb callback, int mode, void *payload);

/** @} */

GIT_END_DECL
#endif
