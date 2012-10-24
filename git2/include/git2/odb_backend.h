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

/**
 * @file git2/backend.h
 * @brief Git custom backend functions
 * @defgroup git_backend Git custom backend API
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

struct git_odb_stream;

/** An instance for a custom backend */
struct git_odb_backend {
	git_odb *odb;

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
			unsigned int);

	int (* read_header)(
			size_t *, git_otype *,
			struct git_odb_backend *,
			const git_oid *);

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

	void (* free)(struct git_odb_backend *);
};

/** Streaming mode */
enum {
	GIT_STREAM_RDONLY = (1 << 1),
	GIT_STREAM_WRONLY = (1 << 2),
	GIT_STREAM_RW = (GIT_STREAM_RDONLY | GIT_STREAM_WRONLY),
};

/** A stream to read/write from a backend */
struct git_odb_stream {
	struct git_odb_backend *backend;
	int mode;

	int (*read)(struct git_odb_stream *stream, char *buffer, size_t len);
	int (*write)(struct git_odb_stream *stream, const char *buffer, size_t len);
	int (*finalize_write)(git_oid *oid_p, struct git_odb_stream *stream);
	void (*free)(struct git_odb_stream *stream);
};

GIT_EXTERN(int) git_odb_backend_pack(git_odb_backend **backend_out, const char *objects_dir);
GIT_EXTERN(int) git_odb_backend_loose(git_odb_backend **backend_out, const char *objects_dir, int compression_level, int do_fsync);

GIT_END_DECL

#endif
