# Copyright (c) 2012 The Chromium Embedded Framework Authors. All rights
# reserved. Use of this source code is governed by a BSD-style license that
# can be found in the LICENSE file.

import os
import sys
import urllib

def check_url(url):
  """ Check the URL and raise an exception if invalid. """
  if ':' in url[:7]:
    parts = url.split(':', 1)
    if (parts[0] == 'http' or parts[0] == 'https' or parts[0] == 'svn') and \
        parts[1] == urllib.quote(parts[1]):
      return url
  sys.stderr.write('Invalid URL: '+url+"\n")
  raise Exception('Invalid URL: '+url)

def get_svn_info(path):
  """ Retrieves the URL and revision from svn info. """
  url = 'None'
  rev = 'None'
  if path[0:4] == 'http' or os.path.exists(path):
    try:
      stream = os.popen('svn info '+path)
      for line in stream:
        if line[0:4] == "URL:":
          url = check_url(line[5:-1])
        elif line[0:9] == "Revision:":
          rev = str(int(line[10:-1]))
    except IOError, (errno, strerror):
      sys.stderr.write('Failed to read svn info: '+strerror+"\n")
      raise
  return {'url': url, 'revision': rev}

def get_revision(path = '.'):
  """ Retrieves the revision from svn info. """
  info = get_svn_info(path)
  if info['revision'] == 'None':
    raise Exception('Unable to retrieve SVN revision for "'+path+'"')
  return info['revision']

def get_changed_files(path = '.'):
  """ Retrieves the list of changed files from svn status. """
  files = []
  if os.path.exists(path):
    try:
      stream = os.popen('svn status '+path)
      for line in stream:
        status = line[0]
        # Return paths with add, modify and switch status.
        if status == 'A' or status == 'M' or status == 'S':
          files.append(line[8:].strip())
    except IOError, (errno, strerror):
      sys.stderr.write('Failed to read svn status: '+strerror+"\n")
      raise
  return files
