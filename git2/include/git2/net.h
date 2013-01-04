/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_net_h__
#define INCLUDE_git_net_h__

#include "common.h"
#include "oid.h"
#include "types.h"

/**
 * @file git2/net.h
 * @brief Git networking declarations
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

#define GIT_DEFAULT_PORT "9418"

/*
 * We need this because we need to know whether we should call
 * git-upload-pack or git-receive-pack on the remote end when get_refs
 * gets called.
 */

typedef enum {
	GIT_DIRECTION_FETCH = 0,
	GIT_DIRECTION_PUSH  = 1
} git_direction;


/**
 * Remote head description, given out on `ls` calls.
 */
struct git_remote_head {
	int local:1; /* available locally */
	git_oid oid;
	git_oid loid;
	char *name;
};

/**
 * Callback for listing the remote heads
 */
typedef int (*git_headlist_cb)(git_remote_head *rhead, void *payload);

/** @} */
GIT_END_DECL
#endif
