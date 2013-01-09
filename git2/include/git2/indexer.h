/*
 * Copyright (C) the libgit2 contributors. All rights reserved.
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
typedef struct git_transfer_progress {
	unsigned int total_objects;
	unsigned int indexed_objects;
	unsigned int received_objects;
	size_t received_bytes;
} git_transfer_progress;


/**
 * Type for progress callbacks during indexing
 */
typedef void (*git_transfer_progress_callback)(const git_transfer_progress *stats, void *payload);

typedef struct git_indexer git_indexer;
typedef struct git_indexer_stream git_indexer_stream;

/**
 * Create a new streaming indexer instance
 *
 * @param out where to store the indexer instance
 * @param path to the directory where the packfile should be stored
 * @param progress_cb function to call with progress information
 * @param progress_payload payload for the progress callback
 */
GIT_EXTERN(int) git_indexer_stream_new(
		git_indexer_stream **out,
		const char *path,
		git_transfer_progress_callback progress_cb,
		void *progress_cb_payload);

/**
 * Add data to the indexer
 *
 * @param idx the indexer
 * @param data the data to add
 * @param size the size of the data in bytes
 * @param stats stat storage
 */
GIT_EXTERN(int) git_indexer_stream_add(git_indexer_stream *idx, const void *data, size_t size, git_transfer_progress *stats);

/**
 * Finalize the pack and index
 *
 * Resolve any pending deltas and write out the index file
 *
 * @param idx the indexer
 */
GIT_EXTERN(int) git_indexer_stream_finalize(git_indexer_stream *idx, git_transfer_progress *stats);

/**
 * Get the packfile's hash
 *
 * A packfile's name is derived from the sorted hashing of all object
 * names. This is only correct after the index has been finalized.
 *
 * @param idx the indexer instance
 */
GIT_EXTERN(const git_oid *) git_indexer_stream_hash(const git_indexer_stream *idx);

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
GIT_EXTERN(int) git_indexer_run(git_indexer *idx, git_transfer_progress *stats);

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
GIT_EXTERN(const git_oid *) git_indexer_hash(const git_indexer *idx);

/**
 * Free the indexer and its resources
 *
 * @param idx the indexer to free
 */
GIT_EXTERN(void) git_indexer_free(git_indexer *idx);

GIT_END_DECL

#endif
