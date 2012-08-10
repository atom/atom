#!/usr/bin/env python

# Copyright (c) 2012 Google Inc. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

import shlex
import sys

# Trim quotes
sys.argv[1], = shlex.split(sys.argv[1])

f = open(sys.argv[1], 'w+')
f.write('Hello from touch.py\n')
f.close()
