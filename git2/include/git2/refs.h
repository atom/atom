/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_refs_h__
#define INCLUDE_git_refs_h__

#include "common.h"
#include "types.h"
#include "oid.h"
#include "strarray.h"

/**
 * @file git2/refs.h
 * @brief Git reference management routines
 * @defgroup git_reference Git reference management routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Lookup a reference by name in a repository.
 *
 * The returned reference must be freed by the user.
 *
 * The name will be checked for validity.
 * See `git_reference_create_symbolic()` for rules about valid names.
 *
 * @param out pointer to the looked-up reference
 * @param repo the repository to look up the reference
 * @param name the long name for the reference (e.g. HEAD, refs/heads/master, refs/tags/v0.1.0, ...)
 * @return 0 on success, ENOTFOUND, EINVALIDSPEC or an error code.
 */
GIT_EXTERN(int) git_reference_lookup(git_reference **out, git_repository *repo, const char *name);

/**
 * Lookup a reference by name and resolve immediately to OID.
 *
 * This function provides a quick way to resolve a reference name straight
 * through to the object id that it refers to.  This avoids having to
 * allocate or free any `git_reference` objects for simple situations.
 *
 * The name will be checked for validity.
 * See `git_reference_create_symbolic()` for rules about valid names.
 *
 * @param out Pointer to oid to be filled in
 * @param repo The repository in which to look up the reference
 * @param name The long name for the reference
 * @return 0 on success, ENOTFOUND, EINVALIDSPEC or an error code.
 */
GIT_EXTERN(int) git_reference_name_to_id(
	git_oid *out, git_repository *repo, const char *name);

/**
 * Create a new symbolic reference.
 *
 * A symbolic reference is a reference name that refers to another
 * reference name.  If the other name moves, the symbolic name will move,
 * too.  As a simple example, the "HEAD" reference might refer to
 * "refs/heads/master" while on the "master" branch of a repository.
 *
 * The symbolic reference will be created in the repository and written to
 * the disk.  The generated reference object must be freed by the user.
 *
 * Valid reference names must follow one of two patterns:
 *
 * 1. Top-level names must contain only capital letters and underscores,
 *    and must begin and end with a letter. (e.g. "HEAD", "ORIG_HEAD").
 * 2. Names prefixed with "refs/" can be almost anything.  You must avoid
 *    the characters '~', '^', ':', '\\', '?', '[', and '*', and the
 *    sequences ".." and "@{" which have special meaning to revparse.
 *
 * This function will return an error if a reference already exists with the
 * given name unless `force` is true, in which case it will be overwritten.
 *
 * @param out Pointer to the newly created reference
 * @param repo Repository where that reference will live
 * @param name The name of the reference
 * @param target The target of the reference
 * @param force Overwrite existing references
 * @return 0 on success, EEXISTS, EINVALIDSPEC or an error code
 */
GIT_EXTERN(int) git_reference_symbolic_create(git_reference **out, git_repository *repo, const char *name, const char *target, int force);

/**
 * Create a new direct reference.
 *
 * A direct reference (also called an object id reference) refers directly
 * to a specific object id (a.k.a. OID or SHA) in the repository.  The id
 * permanently refers to the object (although the reference itself can be
 * moved).  For example, in libgit2 the direct ref "refs/tags/v0.17.0"
 * refers to OID 5b9fac39d8a76b9139667c26a63e6b3f204b3977.
 *
 * The direct reference will be created in the repository and written to
 * the disk.  The generated reference object must be freed by the user.
 *
 * Valid reference names must follow one of two patterns:
 *
 * 1. Top-level names must contain only capital letters and underscores,
 *    and must begin and end with a letter. (e.g. "HEAD", "ORIG_HEAD").
 * 2. Names prefixed with "refs/" can be almost anything.  You must avoid
 *    the characters '~', '^', ':', '\\', '?', '[', and '*', and the
 *    sequences ".." and "@{" which have special meaning to revparse.
 *
 * This function will return an error if a reference already exists with the
 * given name unless `force` is true, in which case it will be overwritten.
 *
 * @param out Pointer to the newly created reference
 * @param repo Repository where that reference will live
 * @param name The name of the reference
 * @param id The object id pointed to by the reference.
 * @param force Overwrite existing references
 * @return 0 on success, EEXISTS, EINVALIDSPEC or an error code
 */
GIT_EXTERN(int) git_reference_create(git_reference **out, git_repository *repo, const char *name, const git_oid *id, int force);

/**
 * Get the OID pointed to by a direct reference.
 *
 * Only available if the reference is direct (i.e. an object id reference,
 * not a symbolic one).
 *
 * To find the OID of a symbolic ref, call `git_reference_resolve()` and
 * then this function (or maybe use `git_reference_name_to_oid()` to
 * directly resolve a reference name all the way through to an OID).
 *
 * @param ref The reference
 * @return a pointer to the oid if available, NULL otherwise
 */
GIT_EXTERN(const git_oid *) git_reference_target(const git_reference *ref);

/**
 * Get full name to the reference pointed to by a symbolic reference.
 *
 * Only available if the reference is symbolic.
 *
 * @param ref The reference
 * @return a pointer to the name if available, NULL otherwise
 */
GIT_EXTERN(const char *) git_reference_symbolic_target(const git_reference *ref);

/**
 * Get the type of a reference.
 *
 * Either direct (GIT_REF_OID) or symbolic (GIT_REF_SYMBOLIC)
 *
 * @param ref The reference
 * @return the type
 */
GIT_EXTERN(git_ref_t) git_reference_type(const git_reference *ref);

/**
 * Get the full name of a reference.
 *
 * See `git_reference_create_symbolic()` for rules about valid names.
 *
 * @param ref The reference
 * @return the full name for the ref
 */
GIT_EXTERN(const char *) git_reference_name(const git_reference *ref);

/**
 * Resolve a symbolic reference to a direct reference.
 *
 * This method iteratively peels a symbolic reference until it resolves to
 * a direct reference to an OID.
 *
 * The peeled reference is returned in the `resolved_ref` argument, and
 * must be freed manually once it's no longer needed.
 *
 * If a direct reference is passed as an argument, a copy of that
 * reference is returned. This copy must be manually freed too.
 *
 * @param resolved_ref Pointer to the peeled reference
 * @param ref The reference
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reference_resolve(git_reference **out, const git_reference *ref);

/**
 * Get the repository where a reference resides.
 *
 * @param ref The reference
 * @return a pointer to the repo
 */
GIT_EXTERN(git_repository *) git_reference_owner(const git_reference *ref);

/**
 * Set the symbolic target of a reference.
 *
 * The reference must be a symbolic reference, otherwise this will fail.
 *
 * The reference will be automatically updated in memory and on disk.
 *
 * The target name will be checked for validity.
 * See `git_reference_create_symbolic()` for rules about valid names.
 *
 * @param ref The reference
 * @param target The new target for the reference
 * @return 0 on success, EINVALIDSPEC or an error code
 */
GIT_EXTERN(int) git_reference_symbolic_set_target(git_reference *ref, const char *target);

/**
 * Set the OID target of a reference.
 *
 * The reference must be a direct reference, otherwise this will fail.
 *
 * The reference will be automatically updated in memory and on disk.
 *
 * @param ref The reference
 * @param id The new target OID for the reference
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reference_set_target(git_reference *ref, const git_oid *id);

/**
 * Rename an existing reference.
 *
 * This method works for both direct and symbolic references.
 *
 * The new name will be checked for validity.
 * See `git_reference_create_symbolic()` for rules about valid names.
 *
 * The given git_reference will be updated in place.
 *
 * The reference will be immediately renamed in-memory and on disk.
 *
 * If the `force` flag is not enabled, and there's already
 * a reference with the given name, the renaming will fail.
 *
 * IMPORTANT:
 * The user needs to write a proper reflog entry if the
 * reflog is enabled for the repository. We only rename
 * the reflog if it exists.
 *
 * @param ref The reference to rename
 * @param name The new name for the reference
 * @param force Overwrite an existing reference
 * @return 0 on success, EINVALIDSPEC, EEXISTS or an error code
 *
 */
GIT_EXTERN(int) git_reference_rename(git_reference *ref, const char *name, int force);

/**
 * Delete an existing reference.
 *
 * This method works for both direct and symbolic references.
 *
 * The reference will be immediately removed on disk and from memory
 * (i.e. freed). The given reference pointer will no longer be valid.
 *
 * @param ref The reference to remove
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reference_delete(git_reference *ref);

/**
 * Pack all the loose references in the repository.
 *
 * This method will load into the cache all the loose
 * references on the repository and update the
 * `packed-refs` file with them.
 *
 * Once the `packed-refs` file has been written properly,
 * the loose references will be removed from disk.
 *
 * @param repo Repository where the loose refs will be packed
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reference_packall(git_repository *repo);

/**
 * Fill a list with all the references that can be found in a repository.
 *
 * Using the `list_flags` parameter, the listed references may be filtered
 * by type (`GIT_REF_OID` or `GIT_REF_SYMBOLIC`) or using a bitwise OR of
 * `git_ref_t` values.  To include packed refs, include `GIT_REF_PACKED`.
 * For convenience, use the value `GIT_REF_LISTALL` to obtain all
 * references, including packed ones.
 *
 * The string array will be filled with the names of all references; these
 * values are owned by the user and should be free'd manually when no
 * longer needed, using `git_strarray_free()`.
 *
 * @param array Pointer to a git_strarray structure where
 *		the reference names will be stored
 * @param repo Repository where to find the refs
 * @param list_flags Filtering flags for the reference listing
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reference_list(git_strarray *array, git_repository *repo, unsigned int list_flags);

typedef int (*git_reference_foreach_cb)(const char *refname, void *payload);

/**
 * Perform a callback on each reference in the repository.
 *
 * Using the `list_flags` parameter, the references may be filtered by
 * type (`GIT_REF_OID` or `GIT_REF_SYMBOLIC`) or using a bitwise OR of
 * `git_ref_t` values.  To include packed refs, include `GIT_REF_PACKED`.
 * For convenience, use the value `GIT_REF_LISTALL` to obtain all
 * references, including packed ones.
 *
 * The `callback` function will be called for each reference in the
 * repository, receiving the name of the reference and the `payload` value
 * passed to this method.  Returning a non-zero value from the callback
 * will terminate the iteration.
 *
 * @param repo Repository where to find the refs
 * @param list_flags Filtering flags for the reference listing.
 * @param callback Function which will be called for every listed ref
 * @param payload Additional data to pass to the callback
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_reference_foreach(
	git_repository *repo,
	unsigned int list_flags,
	git_reference_foreach_cb callback,
	void *payload);

/**
 * Check if a reference has been loaded from a packfile.
 *
 * @param ref A git reference
 * @return 0 in case it's not packed; 1 otherwise
 */
GIT_EXTERN(int) git_reference_is_packed(git_reference *ref);

/**
 * Reload a reference from disk.
 *
 * Reference pointers can become outdated if the Git repository is
 * accessed simultaneously by other clients while the library is open.
 *
 * This method forces a reload of the reference from disk, to ensure that
 * the provided information is still reliable.
 *
 * If the reload fails (e.g. the reference no longer exists on disk, or
 * has become corrupted), an error code will be returned and the reference
 * pointer will be invalidated and freed.
 *
 * @param ref The reference to reload
 * @return 0 on success, or an error code
 */
GIT_EXTERN(int) git_reference_reload(git_reference *ref);

/**
 * Free the given reference.
 *
 * @param ref git_reference
 */
GIT_EXTERN(void) git_reference_free(git_reference *ref);

/**
 * Compare two references.
 *
 * @param ref1 The first git_reference
 * @param ref2 The second git_reference
 * @return 0 if the same, else a stable but meaningless ordering.
 */
GIT_EXTERN(int) git_reference_cmp(git_reference *ref1, git_reference *ref2);

/**
 * Perform a callback on each reference in the repository whose name
 * matches the given pattern.
 *
 * This function acts like `git_reference_foreach()` with an additional
 * pattern match being applied to the reference name before issuing the
 * callback function.  See that function for more information.
 *
 * The pattern is matched using fnmatch or "glob" style where a '*' matches
 * any sequence of letters, a '?' matches any letter, and square brackets
 * can be used to define character ranges (such as "[0-9]" for digits).
 *
 * @param repo Repository where to find the refs
 * @param glob Pattern to match (fnmatch-style) against reference name.
 * @param list_flags Filtering flags for the reference listing.
 * @param callback Function which will be called for every listed ref
 * @param payload Additional data to pass to the callback
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_reference_foreach_glob(
	git_repository *repo,
	const char *glob,
	unsigned int list_flags,
	git_reference_foreach_cb callback,
	void *payload);

/**
 * Check if a reflog exists for the specified reference.
 *
 * @param ref A git reference
 *
 * @return 0 when no reflog can be found, 1 when it exists;
 * otherwise an error code.
 */
GIT_EXTERN(int) git_reference_has_log(git_reference *ref);

/**
 * Check if a reference is a local branch.
 *
 * @param ref A git reference
 *
 * @return 1 when the reference lives in the refs/heads
 * namespace; 0 otherwise.
 */
GIT_EXTERN(int) git_reference_is_branch(git_reference *ref);

/**
 * Check if a reference is a remote tracking branch
 *
 * @param ref A git reference
 *
 * @return 1 when the reference lives in the refs/remotes
 * namespace; 0 otherwise.
 */
GIT_EXTERN(int) git_reference_is_remote(git_reference *ref);


typedef enum {
	GIT_REF_FORMAT_NORMAL = 0,

	/**
	 * Control whether one-level refnames are accepted
	 * (i.e., refnames that do not contain multiple /-separated
	 * components). Those are expected to be written only using
	 * uppercase letters and underscore (FETCH_HEAD, ...)
	 */
	GIT_REF_FORMAT_ALLOW_ONELEVEL = (1 << 0),

	/**
	 * Interpret the provided name as a reference pattern for a
	 * refspec (as used with remote repositories). If this option
	 * is enabled, the name is allowed to contain a single * (<star>)
	 * in place of a one full pathname component
	 * (e.g., foo/<star>/bar but not foo/bar<star>).
	 */
	GIT_REF_FORMAT_REFSPEC_PATTERN = (1 << 1),
} git_reference_normalize_t;

/**
 * Normalize reference name and check validity.
 *
 * This will normalize the reference name by removing any leading slash
 * '/' characters and collapsing runs of adjacent slashes between name
 * components into a single slash.
 *
 * Once normalized, if the reference name is valid, it will be returned in
 * the user allocated buffer.
 *
 * See `git_reference_create_symbolic()` for rules about valid names.
 *
 * @param buffer_out User allocated buffer to store normalized name
 * @param buffer_size Size of buffer_out
 * @param name Reference name to be checked.
 * @param flags Flags to constrain name validation rules - see the
 *              GIT_REF_FORMAT constants above.
 * @return 0 on success, GIT_EBUFS if buffer is too small, EINVALIDSPEC
 * or an error code.
 */
GIT_EXTERN(int) git_reference_normalize_name(
	char *buffer_out,
	size_t buffer_size,
	const char *name,
	unsigned int flags);

/**
 * Recursively peel reference until object of the specified type is found.
 *
 * The retrieved `peeled` object is owned by the repository
 * and should be closed with the `git_object_free` method.
 *
 * If you pass `GIT_OBJ_ANY` as the target type, then the object
 * will be peeled until a non-tag object is met.
 *
 * @param peeled Pointer to the peeled git_object
 * @param ref The reference to be processed
 * @param target_type The type of the requested object (GIT_OBJ_COMMIT,
 * GIT_OBJ_TAG, GIT_OBJ_TREE, GIT_OBJ_BLOB or GIT_OBJ_ANY).
 * @return 0 on success, GIT_EAMBIGUOUS, GIT_ENOTFOUND or an error code
 */
GIT_EXTERN(int) git_reference_peel(
	git_object **out,
	git_reference *ref,
	git_otype type);

/**
 * Ensure the reference name is well-formed.
 *
 * Valid reference names must follow one of two patterns:
 *
 * 1. Top-level names must contain only capital letters and underscores,
 *    and must begin and end with a letter. (e.g. "HEAD", "ORIG_HEAD").
 * 2. Names prefixed with "refs/" can be almost anything.  You must avoid
 *    the characters '~', '^', ':', '\\', '?', '[', and '*', and the
 *    sequences ".." and "@{" which have special meaning to revparse.
 *
 * @param refname name to be checked.
 * @return 1 if the reference name is acceptable; 0 if it isn't
 */
GIT_EXTERN(int) git_reference_is_valid_name(const char *refname);

/** @} */
GIT_END_DECL
#endif
