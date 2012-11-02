/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_pack_h__
#define INCLUDE_git_pack_h__

#include "common.h"
#include "oid.h"

/**
 * @file git2/pack.h
 * @brief Git pack management routines
 * @defgroup git_pack Git pack management routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Initialize a new packbuilder
 *
 * @param out The new packbuilder object
 * @param repo The repository
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_packbuilder_new(git_packbuilder **out, git_repository *repo);

/**
 * Set number of threads to spawn
 *
 * By default, libgit2 won't spawn any threads at all;
 * when set to 0, libgit2 will autodetect the number of
 * CPUs.
 *
 * @param pb The packbuilder
 * @param n Number of threads to spawn
 */
GIT_EXTERN(void) git_packbuilder_set_threads(git_packbuilder *pb, unsigned int n);

/**
 * Insert a single object
 *
 * For an optimal pack it's mandatory to insert objects in recency order,
 * commits followed by trees and blobs.
 *
 * @param pb The packbuilder
 * @param oid The oid of the commit
 * @param oid The name; might be NULL
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_packbuilder_insert(git_packbuilder *pb, const git_oid *oid,	const char *name);

/**
 * Insert a root tree object
 *
 * This will add the tree as well as all referenced trees and blobs.
 *
 * @param pb The packbuilder
 * @param oid The oid of the root tree
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_packbuilder_insert_tree(git_packbuilder *pb, const git_oid *oid);

/**
 * Write the new pack and the corresponding index to path
 *
 * @param pb The packbuilder
 * @param path Directory to store the new pack and index
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_packbuilder_write(git_packbuilder *pb, const char *file);

/**
 * Free the packbuilder and all associated data
 *
 * @param pb The packbuilder
 */
GIT_EXTERN(void) git_packbuilder_free(git_packbuilder *pb);

/** @} */
GIT_END_DECL
#endif
