/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_odb_backend_h__
#define INCLUDE_git_odb_backend_h__

#include "common.h"
#include "types.h"
#include "oid.h"
#include "indexer.h"

/**
 * @file git2/backend.h
 * @brief Git custom backend functions
 * @defgroup git_backend Git custom backend API
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

struct git_odb_stream;
struct git_odb_writepack;

/**
 * Function type for callbacks from git_odb_foreach.
 */
typedef int (*git_odb_foreach_cb)(const git_oid *id, void *payload);

/**
 * An instance for a custom backend
 */
struct git_odb_backend {
	unsigned int version;
	git_odb *odb;

	/* read and read_prefix each return to libgit2 a buffer which
	 * will be freed later. The buffer should be allocated using
	 * the function git_odb_backend_malloc to ensure that it can
	 * be safely freed later. */
	int (* read)(
			void **, size_t *, git_otype *,
			struct git_odb_backend *,
			const git_oid *);

	/* To find a unique object given a prefix
	 * of its oid.
	 * The oid given must be so that the
	 * remaining (GIT_OID_HEXSZ - len)*4 bits
	 * are 0s.
	 */
	int (* read_prefix)(
			git_oid *,
			void **, size_t *, git_otype *,
			struct git_odb_backend *,
			const git_oid *,
			size_t);

	int (* read_header)(
			size_t *, git_otype *,
			struct git_odb_backend *,
			const git_oid *);

	/* The writer may assume that the object
	 * has already been hashed and is passed
	 * in the first parameter.
	 */
	int (* write)(
			git_oid *,
			struct git_odb_backend *,
			const void *,
			size_t,
			git_otype);

	int (* writestream)(
			struct git_odb_stream **,
			struct git_odb_backend *,
			size_t,
			git_otype);

	int (* readstream)(
			struct git_odb_stream **,
			struct git_odb_backend *,
			const git_oid *);

	int (* exists)(
			struct git_odb_backend *,
			const git_oid *);

	int (* foreach)(
			struct git_odb_backend *,
			git_odb_foreach_cb cb,
			void *payload);

	int (* writepack)(
			struct git_odb_writepack **,
			struct git_odb_backend *,
			git_transfer_progress_callback progress_cb,
			void *progress_payload);

	void (* free)(struct git_odb_backend *);
};

#define GIT_ODB_BACKEND_VERSION 1
#define GIT_ODB_BACKEND_INIT {GIT_ODB_BACKEND_VERSION}

/** Streaming mode */
enum {
	GIT_STREAM_RDONLY = (1 << 1),
	GIT_STREAM_WRONLY = (1 << 2),
	GIT_STREAM_RW = (GIT_STREAM_RDONLY | GIT_STREAM_WRONLY),
};

/** A stream to read/write from a backend */
struct git_odb_stream {
	struct git_odb_backend *backend;
	unsigned int mode;

	int (*read)(struct git_odb_stream *stream, char *buffer, size_t len);
	int (*write)(struct git_odb_stream *stream, const char *buffer, size_t len);
	int (*finalize_write)(git_oid *oid_p, struct git_odb_stream *stream);
	void (*free)(struct git_odb_stream *stream);
};

/** A stream to write a pack file to the ODB */
struct git_odb_writepack {
	struct git_odb_backend *backend;

	int (*add)(struct git_odb_writepack *writepack, const void *data, size_t size, git_transfer_progress *stats);
	int (*commit)(struct git_odb_writepack *writepack, git_transfer_progress *stats);
	void (*free)(struct git_odb_writepack *writepack);
};

GIT_EXTERN(void *) git_odb_backend_malloc(git_odb_backend *backend, size_t len);

/**
 * Constructors for in-box ODB backends.
 */
GIT_EXTERN(int) git_odb_backend_pack(git_odb_backend **out, const char *objects_dir);
GIT_EXTERN(int) git_odb_backend_loose(git_odb_backend **out, const char *objects_dir, int compression_level, int do_fsync);
GIT_EXTERN(int) git_odb_backend_one_pack(git_odb_backend **out, const char *index_file);

GIT_END_DECL

#endif
