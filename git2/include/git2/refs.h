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

/**
 * @file git2/refs.h
 * @brief Git reference management routines
 * @defgroup git_reference Git reference management routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Lookup a reference by its name in a repository.
 *
 * The generated reference must be freed by the user.
 *
 * @param reference_out pointer to the looked-up reference
 * @param repo the repository to look up the reference
 * @param name the long name for the reference (e.g. HEAD, ref/heads/master, refs/tags/v0.1.0, ...)
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reference_lookup(git_reference **reference_out, git_repository *repo, const char *name);

/**
 * Lookup a reference by name and resolve immediately to OID.
 *
 * @param oid Pointer to oid to be filled in
 * @param repo The repository in which to look up the reference
 * @param name The long name for the reference
 * @return 0 on success, -1 if name could not be resolved
 */
GIT_EXTERN(int) git_reference_name_to_oid(
	git_oid *out, git_repository *repo, const char *name);

/**
 * Create a new symbolic reference.
 *
 * The reference will be created in the repository and written
 * to the disk.
 *
 * The generated reference must be freed by the user.
 *
 * If `force` is true and there already exists a reference
 * with the same name, it will be overwritten.
 *
 * @param ref_out Pointer to the newly created reference
 * @param repo Repository where that reference will live
 * @param name The name of the reference
 * @param target The target of the reference
 * @param force Overwrite existing references
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reference_create_symbolic(git_reference **ref_out, git_repository *repo, const char *name, const char *target, int force);

/**
 * Create a new object id reference.
 *
 * The reference will be created in the repository and written
 * to the disk.
 *
 * The generated reference must be freed by the user.
 *
 * If `force` is true and there already exists a reference
 * with the same name, it will be overwritten.
 *
 * @param ref_out Pointer to the newly created reference
 * @param repo Repository where that reference will live
 * @param name The name of the reference
 * @param id The object id pointed to by the reference.
 * @param force Overwrite existing references
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reference_create_oid(git_reference **ref_out, git_repository *repo, const char *name, const git_oid *id, int force);

/**
 * Get the OID pointed to by a reference.
 *
 * Only available if the reference is direct (i.e. not symbolic)
 *
 * @param ref The reference
 * @return a pointer to the oid if available, NULL otherwise
 */
GIT_EXTERN(const git_oid *) git_reference_oid(git_reference *ref);

/**
 * Get full name to the reference pointed by this reference
 *
 * Only available if the reference is symbolic
 *
 * @param ref The reference
 * @return a pointer to the name if available, NULL otherwise
 */
GIT_EXTERN(const char *) git_reference_target(git_reference *ref);

/**
 * Get the type of a reference
 *
 * Either direct (GIT_REF_OID) or symbolic (GIT_REF_SYMBOLIC)
 *
 * @param ref The reference
 * @return the type
 */
GIT_EXTERN(git_ref_t) git_reference_type(git_reference *ref);

/**
 * Get the full name of a reference
 *
 * @param ref The reference
 * @return the full name for the ref
 */
GIT_EXTERN(const char *) git_reference_name(git_reference *ref);

/**
 * Resolve a symbolic reference
 *
 * Thie method iteratively peels a symbolic reference
 * until it resolves to a direct reference to an OID.
 *
 * The peeled reference is returned in the `resolved_ref`
 * argument, and must be freed manually once it's no longer
 * needed.
 *
 * If a direct reference is passed as an argument,
 * a copy of that reference is returned. This copy must
 * be manually freed too.
 *
 * @param resolved_ref Pointer to the peeled reference
 * @param ref The reference
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reference_resolve(git_reference **resolved_ref, git_reference *ref);

/**
 * Get the repository where a reference resides
 *
 * @param ref The reference
 * @return a pointer to the repo
 */
GIT_EXTERN(git_repository *) git_reference_owner(git_reference *ref);

/**
 * Set the symbolic target of a reference.
 *
 * The reference must be a symbolic reference, otherwise
 * this method will fail.
 *
 * The reference will be automatically updated in
 * memory and on disk.
 *
 * @param ref The reference
 * @param target The new target for the reference
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reference_set_target(git_reference *ref, const char *target);

/**
 * Set the OID target of a reference.
 *
 * The reference must be a direct reference, otherwise
 * this method will fail.
 *
 * The reference will be automatically updated in
 * memory and on disk.
 *
 * @param ref The reference
 * @param id The new target OID for the reference
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reference_set_oid(git_reference *ref, const git_oid *id);

/**
 * Rename an existing reference
 *
 * This method works for both direct and symbolic references.
 * The new name will be checked for validity and may be
 * modified into a normalized form.
 *
 * The given git_reference will be updated in place.
 *
 * The reference will be immediately renamed in-memory
 * and on disk.
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
 * @param new_name The new name for the reference
 * @param force Overwrite an existing reference
 * @return 0 or an error code
 *
 */
GIT_EXTERN(int) git_reference_rename(git_reference *ref, const char *new_name, int force);

/**
 * Delete an existing reference
 *
 * This method works for both direct and symbolic references.
 *
 * The reference will be immediately removed on disk and from
 * memory. The given reference pointer will no longer be valid.
 *
 * @param ref The reference to remove
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reference_delete(git_reference *ref);

/**
 * Pack all the loose references in the repository
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
 * Fill a list with all the references that can be found
 * in a repository.
 *
 * The listed references may be filtered by type, or using
 * a bitwise OR of several types. Use the magic value
 * `GIT_REF_LISTALL` to obtain all references, including
 * packed ones.
 *
 * The string array will be filled with the names of all
 * references; these values are owned by the user and
 * should be free'd manually when no longer needed, using
 * `git_strarray_free`.
 *
 * @param array Pointer to a git_strarray structure where
 *		the reference names will be stored
 * @param repo Repository where to find the refs
 * @param list_flags Filtering flags for the reference
 *		listing.
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reference_list(git_strarray *array, git_repository *repo, unsigned int list_flags);


/**
 * Perform an operation on each reference in the repository
 *
 * The processed references may be filtered by type, or using
 * a bitwise OR of several types. Use the magic value
 * `GIT_REF_LISTALL` to obtain all references, including
 * packed ones.
 *
 * The `callback` function will be called for each of the references
 * in the repository, and will receive the name of the reference and
 * the `payload` value passed to this method.
 *
 * @param repo Repository where to find the refs
 * @param list_flags Filtering flags for the reference
 *		listing.
 * @param callback Function which will be called for every listed ref
 * @param payload Additional data to pass to the callback
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reference_foreach(git_repository *repo, unsigned int list_flags, int (*callback)(const char *, void *), void *payload);

/**
 * Check if a reference has been loaded from a packfile
 *
 * @param ref A git reference
 * @return 0 in case it's not packed; 1 otherwise
 */
GIT_EXTERN(int) git_reference_is_packed(git_reference *ref);

/**
 * Reload a reference from disk
 *
 * Reference pointers may become outdated if the Git
 * repository is accessed simultaneously by other clients
 * whilt the library is open.
 *
 * This method forces a reload of the reference from disk,
 * to ensure that the provided information is still
 * reliable.
 *
 * If the reload fails (e.g. the reference no longer exists
 * on disk, or has become corrupted), an error code will be
 * returned and the reference pointer will be invalidated.
 *
 * @param ref The reference to reload
 * @return 0 on success, or an error code
 */
GIT_EXTERN(int) git_reference_reload(git_reference *ref);

/**
 * Free the given reference
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

/** @} */
GIT_END_DECL
#endif
