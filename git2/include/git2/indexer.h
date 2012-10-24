/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef _INCLUDE_git_indexer_h__
#define _INCLUDE_git_indexer_h__

#include "common.h"
#include "oid.h"

GIT_BEGIN_DECL

/**
 * This is passed as the first argument to the callback to allow the
 * user to see the progress.
 */
typedef struct git_indexer_stats {
	unsigned int total;
	unsigned int processed;
} git_indexer_stats;


typedef struct git_indexer git_indexer;
typedef struct git_indexer_stream git_indexer_stream;

/**
 * Create a new streaming indexer instance
 *
 * @param out where to store the inexer instance
 * @param path to the gitdir (metadata directory)
 */
GIT_EXTERN(int) git_indexer_stream_new(git_indexer_stream **out, const char *gitdir);

/**
 * Add data to the indexer
 *
 * @param idx the indexer
 * @param data the data to add
 * @param size the size of the data
 * @param stats stat storage
 */
GIT_EXTERN(int) git_indexer_stream_add(git_indexer_stream *idx, const void *data, size_t size, git_indexer_stats *stats);

/**
 * Finalize the pack and index
 *
 * Resolve any pending deltas and write out the index file
 *
 * @param idx the indexer
 */
GIT_EXTERN(int) git_indexer_stream_finalize(git_indexer_stream *idx, git_indexer_stats *stats);

/**
 * Get the packfile's hash
 *
 * A packfile's name is derived from the sorted hashing of all object
 * names. This is only correct after the index has been finalized.
 *
 * @param idx the indexer instance
 */
GIT_EXTERN(const git_oid *) git_indexer_stream_hash(git_indexer_stream *idx);

/**
 * Free the indexer and its resources
 *
 * @param idx the indexer to free
 */
GIT_EXTERN(void) git_indexer_stream_free(git_indexer_stream *idx);

/**
 * Create a new indexer instance
 *
 * @param out where to store the indexer instance
 * @param packname the absolute filename of the packfile to index
 */
GIT_EXTERN(int) git_indexer_new(git_indexer **out, const char *packname);

/**
 * Iterate over the objects in the packfile and extract the information
 *
 * Indexing a packfile can be very expensive so this function is
 * expected to be run in a worker thread and the stats used to provide
 * feedback the user.
 *
 * @param idx the indexer instance
 * @param stats storage for the running state
 */
GIT_EXTERN(int) git_indexer_run(git_indexer *idx, git_indexer_stats *stats);

/**
 * Write the index file to disk.
 *
 * The file will be stored as pack-$hash.idx in the same directory as
 * the packfile.
 *
 * @param idx the indexer instance
 */
GIT_EXTERN(int) git_indexer_write(git_indexer *idx);

/**
 * Get the packfile's hash
 *
 * A packfile's name is derived from the sorted hashing of all object
 * names. This is only correct after the index has been written to disk.
 *
 * @param idx the indexer instance
 */
GIT_EXTERN(const git_oid *) git_indexer_hash(git_indexer *idx);

/**
 * Free the indexer and its resources
 *
 * @param idx the indexer to free
 */
GIT_EXTERN(void) git_indexer_free(git_indexer *idx);

GIT_END_DECL

#endif
