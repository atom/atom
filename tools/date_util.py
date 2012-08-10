# Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
# reserved. Use of this source code is governed by a BSD-style license that
# can be found in the LICENSE file.

import datetime

def get_year():
    """ Returns the current year. """
    return str(datetime.datetime.now().year)

def get_date():
    """ Returns the current date. """
    return datetime.datetime.now().strftime('%B %d, %Y')
