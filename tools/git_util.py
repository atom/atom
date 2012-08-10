# Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
# reserved. Use of this source code is governed by a BSD-style license that
# can be found in the LICENSE file

from subprocess import Popen, PIPE

def get_svn_revision(path=".", branch="master"):
    svn_rev = "None"
    cmd = ("git log --grep=^git-svn-id: -n 1 %s" % branch).split()
    try:
        process = Popen(cmd, cwd=path, stdout = PIPE, stderr = PIPE)
        for line in process.stdout:
            if line.find("git-svn-id") > 0:
                svn_rev = line.split("@")[1].split()[0]
                break
    except IOError, (errno, strerror):
        sys.stderr.write('Failed to read git log: ' + strerror + "\n")
        raise
    return svn_rev

def get_changed_files(path="."):
  """ Retrieves the list of changed files. """
  # not implemented
  return []
