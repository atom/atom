/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_types_h__
#define INCLUDE_git_types_h__

#include "common.h"

/**
 * @file git2/types.h
 * @brief libgit2 base & compatibility types
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Cross-platform compatibility types for off_t / time_t
 *
 * NOTE: This needs to be in a public header so that both the library
 * implementation and client applications both agree on the same types.
 * Otherwise we get undefined behavior.
 *
 * Use the "best" types that each platform provides. Currently we truncate
 * these intermediate representations for compatibility with the git ABI, but
 * if and when it changes to support 64 bit types, our code will naturally
 * adapt.
 * NOTE: These types should match those that are returned by our internal
 * stat() functions, for all platforms.
 */
#include <sys/types.h>

#if defined(_MSC_VER)

typedef __int64 git_off_t;
typedef __time64_t git_time_t;

#elif defined(__MINGW32__)

typedef off64_t git_off_t;
typedef __time64_t git_time_t;

#elif defined(__HAIKU__)

typedef __haiku_std_int64 git_off_t;
typedef __haiku_std_int64 git_time_t;

#else /* POSIX */

/*
 * Note: Can't use off_t since if a client program includes <sys/types.h>
 * before us (directly or indirectly), they'll get 32 bit off_t in their client
 * app, even though /we/ define _FILE_OFFSET_BITS=64.
 */
typedef int64_t git_off_t;
typedef int64_t git_time_t;

#endif

/** Basic type (loose or packed) of any Git object. */
typedef enum {
	GIT_OBJ_ANY = -2,		/**< Object can be any of the following */
	GIT_OBJ_BAD = -1,		/**< Object is invalid. */
	GIT_OBJ__EXT1 = 0,		/**< Reserved for future use. */
	GIT_OBJ_COMMIT = 1,		/**< A commit object. */
	GIT_OBJ_TREE = 2,		/**< A tree (directory listing) object. */
	GIT_OBJ_BLOB = 3,		/**< A file revision object. */
	GIT_OBJ_TAG = 4,		/**< An annotated tag object. */
	GIT_OBJ__EXT2 = 5,		/**< Reserved for future use. */
	GIT_OBJ_OFS_DELTA = 6, /**< A delta, base is given by an offset. */
	GIT_OBJ_REF_DELTA = 7, /**< A delta, base is given by object id. */
} git_otype;

/** An open object database handle. */
typedef struct git_odb git_odb;

/** A custom backend in an ODB */
typedef struct git_odb_backend git_odb_backend;

/** An object read from the ODB */
typedef struct git_odb_object git_odb_object;

/** A stream to read/write from the ODB */
typedef struct git_odb_stream git_odb_stream;

/**
 * Representation of an existing git repository,
 * including all its object contents
 */
typedef struct git_repository git_repository;

/** Representation of a generic object in a repository */
typedef struct git_object git_object;

/** Representation of an in-progress walk through the commits in a repo */
typedef struct git_revwalk git_revwalk;

/** Parsed representation of a tag object. */
typedef struct git_tag git_tag;

/** In-memory representation of a blob object. */
typedef struct git_blob git_blob;

/** Parsed representation of a commit object. */
typedef struct git_commit git_commit;

/** Representation of each one of the entries in a tree object. */
typedef struct git_tree_entry git_tree_entry;

/** Representation of a tree object. */
typedef struct git_tree git_tree;

/** Constructor for in-memory trees */
typedef struct git_treebuilder git_treebuilder;

/** Memory representation of an index file. */
typedef struct git_index git_index;

/** Memory representation of a set of config files */
typedef struct git_config git_config;

/** Interface to access a configuration file */
typedef struct git_config_file git_config_file;

/** Representation of a reference log entry */
typedef struct git_reflog_entry git_reflog_entry;

/** Representation of a reference log */
typedef struct git_reflog git_reflog;

/** Representation of a git note */
typedef struct git_note git_note;

/** Time in a signature */
typedef struct git_time {
	git_time_t time; /** time in seconds from epoch */
	int offset; /** timezone offset, in minutes */
} git_time;

/** An action signature (e.g. for committers, taggers, etc) */
typedef struct git_signature {
	char *name; /** full name of the author */
	char *email; /** email of the author */
	git_time when; /** time when the action happened */
} git_signature;

/** In-memory representation of a reference. */
typedef struct git_reference git_reference;

/** Basic type of any Git reference. */
typedef enum {
	GIT_REF_INVALID = 0, /** Invalid reference */
	GIT_REF_OID = 1, /** A reference which points at an object id */
	GIT_REF_SYMBOLIC = 2, /** A reference which points at another reference */
	GIT_REF_PACKED = 4,
	GIT_REF_HAS_PEEL = 8,
	GIT_REF_LISTALL = GIT_REF_OID|GIT_REF_SYMBOLIC|GIT_REF_PACKED,
} git_ref_t;

/** Basic type of any Git branch. */
typedef enum {
	GIT_BRANCH_LOCAL = 1,
	GIT_BRANCH_REMOTE = 2,
} git_branch_t;

typedef struct git_refspec git_refspec;
typedef struct git_remote git_remote;

typedef struct git_remote_head git_remote_head;

/** @} */
GIT_END_DECL

#endif
