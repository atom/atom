/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_odb_h__
#define INCLUDE_git_odb_h__

#include "common.h"
#include "types.h"
#include "oid.h"
#include "odb_backend.h"

/**
 * @file git2/odb.h
 * @brief Git object database routines
 * @defgroup git_odb Git object database routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Create a new object database with no backends.
 *
 * Before the ODB can be used for read/writing, a custom database
 * backend must be manually added using `git_odb_add_backend()`
 *
 * @param out location to store the database pointer, if opened.
 *			Set to NULL if the open failed.
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_odb_new(git_odb **out);

/**
 * Create a new object database and automatically add
 * the two default backends:
 *
 *	- git_odb_backend_loose: read and write loose object files
 *		from disk, assuming `objects_dir` as the Objects folder
 *
 *	- git_odb_backend_pack: read objects from packfiles,
 *		assuming `objects_dir` as the Objects folder which
 *		contains a 'pack/' folder with the corresponding data
 *
 * @param out location to store the database pointer, if opened.
 *			Set to NULL if the open failed.
 * @param objects_dir path of the backends' "objects" directory.
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_odb_open(git_odb **out, const char *objects_dir);

/**
 * Add a custom backend to an existing Object DB
 *
 * The backends are checked in relative ordering, based on the
 * value of the `priority` parameter.
 *
 * Read <odb_backends.h> for more information.
 *
 * @param odb database to add the backend to
 * @param backend pointer to a git_odb_backend instance
 * @param priority Value for ordering the backends queue
 * @return 0 on sucess; error code otherwise
 */
GIT_EXTERN(int) git_odb_add_backend(git_odb *odb, git_odb_backend *backend, int priority);

/**
 * Add a custom backend to an existing Object DB; this
 * backend will work as an alternate.
 *
 * Alternate backends are always checked for objects *after*
 * all the main backends have been exhausted.
 *
 * The backends are checked in relative ordering, based on the
 * value of the `priority` parameter.
 *
 * Writing is disabled on alternate backends.
 *
 * Read <odb_backends.h> for more information.
 *
 * @param odb database to add the backend to
 * @param backend pointer to a git_odb_backend instance
 * @param priority Value for ordering the backends queue
 * @return 0 on sucess; error code otherwise
 */
GIT_EXTERN(int) git_odb_add_alternate(git_odb *odb, git_odb_backend *backend, int priority);

/**
 * Close an open object database.
 *
 * @param db database pointer to close. If NULL no action is taken.
 */
GIT_EXTERN(void) git_odb_free(git_odb *db);

/**
 * Read an object from the database.
 *
 * This method queries all available ODB backends
 * trying to read the given OID.
 *
 * The returned object is reference counted and
 * internally cached, so it should be closed
 * by the user once it's no longer in use.
 *
 * @param out pointer where to store the read object
 * @param db database to search for the object in.
 * @param id identity of the object to read.
 * @return
 * - 0 if the object was read;
 * - GIT_ENOTFOUND if the object is not in the database.
 */
GIT_EXTERN(int) git_odb_read(git_odb_object **out, git_odb *db, const git_oid *id);

/**
 * Read an object from the database, given a prefix
 * of its identifier.
 *
 * This method queries all available ODB backends
 * trying to match the 'len' first hexadecimal
 * characters of the 'short_id'.
 * The remaining (GIT_OID_HEXSZ-len)*4 bits of
 * 'short_id' must be 0s.
 * 'len' must be at least GIT_OID_MINPREFIXLEN,
 * and the prefix must be long enough to identify
 * a unique object in all the backends; the
 * method will fail otherwise.
 *
 * The returned object is reference counted and
 * internally cached, so it should be closed
 * by the user once it's no longer in use.
 *
 * @param out pointer where to store the read object
 * @param db database to search for the object in.
 * @param short_id a prefix of the id of the object to read.
 * @param len the length of the prefix
 * @return 0 if the object was read;
 *	GIT_ENOTFOUND if the object is not in the database.
 *	GIT_EAMBIGUOUS if the prefix is ambiguous (several objects match the prefix)
 */
GIT_EXTERN(int) git_odb_read_prefix(git_odb_object **out, git_odb *db, const git_oid *short_id, unsigned int len);

/**
 * Read the header of an object from the database, without
 * reading its full contents.
 *
 * The header includes the length and the type of an object.
 *
 * Note that most backends do not support reading only the header
 * of an object, so the whole object will be read and then the
 * header will be returned.
 *
 * @param len_p pointer where to store the length
 * @param type_p pointer where to store the type
 * @param db database to search for the object in.
 * @param id identity of the object to read.
 * @return
 * - 0 if the object was read;
 * - GIT_ENOTFOUND if the object is not in the database.
 */
GIT_EXTERN(int) git_odb_read_header(size_t *len_p, git_otype *type_p, git_odb *db, const git_oid *id);

/**
 * Determine if the given object can be found in the object database.
 *
 * @param db database to be searched for the given object.
 * @param id the object to search for.
 * @return
 * - 1, if the object was found
 * - 0, otherwise
 */
GIT_EXTERN(int) git_odb_exists(git_odb *db, const git_oid *id);

/**
 * Write an object directly into the ODB
 *
 * This method writes a full object straight into the ODB.
 * For most cases, it is preferred to write objects through a write
 * stream, which is both faster and less memory intensive, specially
 * for big objects.
 *
 * This method is provided for compatibility with custom backends
 * which are not able to support streaming writes
 *
 * @param oid pointer to store the OID result of the write
 * @param odb object database where to store the object
 * @param data buffer with the data to storr
 * @param len size of the buffer
 * @param type type of the data to store
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_odb_write(git_oid *oid, git_odb *odb, const void *data, size_t len, git_otype type);

/**
 * Open a stream to write an object into the ODB
 *
 * The type and final length of the object must be specified
 * when opening the stream.
 *
 * The returned stream will be of type `GIT_STREAM_WRONLY` and
 * will have the following methods:
 *
 *		- stream->write: write `n` bytes into the stream
 *		- stream->finalize_write: close the stream and store the object in
 *			the odb
 *		- stream->free: free the stream
 *
 * The streaming write won't be effective until `stream->finalize_write`
 * is called and returns without an error
 *
 * The stream must always be free'd or will leak memory.
 *
 * @see git_odb_stream
 *
 * @param stream pointer where to store the stream
 * @param db object database where the stream will write
 * @param size final size of the object that will be written
 * @param type type of the object that will be written
 * @return 0 if the stream was created; error code otherwise
 */
GIT_EXTERN(int) git_odb_open_wstream(git_odb_stream **stream, git_odb *db, size_t size, git_otype type);

/**
 * Open a stream to read an object from the ODB
 *
 * Note that most backends do *not* support streaming reads
 * because they store their objects as compressed/delta'ed blobs.
 *
 * It's recommended to use `git_odb_read` instead, which is
 * assured to work on all backends.
 *
 * The returned stream will be of type `GIT_STREAM_RDONLY` and
 * will have the following methods:
 *
 *		- stream->read: read `n` bytes from the stream
 *		- stream->free: free the stream
 *
 * The stream must always be free'd or will leak memory.
 *
 * @see git_odb_stream
 *
 * @param stream pointer where to store the stream
 * @param db object database where the stream will read from
 * @param oid oid of the object the stream will read from
 * @return 0 if the stream was created; error code otherwise
 */
GIT_EXTERN(int) git_odb_open_rstream(git_odb_stream **stream, git_odb *db, const git_oid *oid);

/**
 * Determine the object-ID (sha1 hash) of a data buffer
 *
 * The resulting SHA-1 OID will the itentifier for the data
 * buffer as if the data buffer it were to written to the ODB.
 *
 * @param id the resulting object-ID.
 * @param data data to hash
 * @param len size of the data
 * @param type of the data to hash
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_odb_hash(git_oid *id, const void *data, size_t len, git_otype type);

/**
 * Read a file from disk and fill a git_oid with the object id
 * that the file would have if it were written to the Object
 * Database as an object of the given type. Similar functionality
 * to git.git's `git hash-object` without the `-w` flag.
 *
 * @param out oid structure the result is written into.
 * @param path file to read and determine object id for
 * @param type the type of the object that will be hashed
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_odb_hashfile(git_oid *out, const char *path, git_otype type);

/**
 * Close an ODB object
 *
 * This method must always be called once a `git_odb_object` is no
 * longer needed, otherwise memory will leak.
 *
 * @param object object to close
 */
GIT_EXTERN(void) git_odb_object_free(git_odb_object *object);

/**
 * Return the OID of an ODB object
 *
 * This is the OID from which the object was read from
 *
 * @param object the object
 * @return a pointer to the OID
 */
GIT_EXTERN(const git_oid *) git_odb_object_id(git_odb_object *object);

/**
 * Return the data of an ODB object
 *
 * This is the uncompressed, raw data as read from the ODB,
 * without the leading header.
 *
 * This pointer is owned by the object and shall not be free'd.
 *
 * @param object the object
 * @return a pointer to the data
 */
GIT_EXTERN(const void *) git_odb_object_data(git_odb_object *object);

/**
 * Return the size of an ODB object
 *
 * This is the real size of the `data` buffer, not the
 * actual size of the object.
 *
 * @param object the object
 * @return the size
 */
GIT_EXTERN(size_t) git_odb_object_size(git_odb_object *object);

/**
 * Return the type of an ODB object
 *
 * @param object the object
 * @return the type
 */
GIT_EXTERN(git_otype) git_odb_object_type(git_odb_object *object);

/** @} */
GIT_END_DECL
#endif
