# Copyright (c) 2009 The Chromium Embedded Framework Authors. All rights
# reserved. Use of this source code is governed by a BSD-style license that
# can be found in the LICENSE file.

import sys
from cef_parser import *
from make_capi_header import *
from make_cpptoc_header import *
from make_cpptoc_impl import *
from make_ctocpp_header import *
from make_ctocpp_impl import *
from make_gypi_file import *
from optparse import OptionParser


# cannot be loaded as a module
if __name__ != "__main__":
    sys.stderr.write('This file cannot be loaded as a module!')
    sys.exit()
    

# parse command-line options
disc = """
This utility generates files for the CEF C++ to C API translation layer.
"""

parser = OptionParser(description=disc)
parser.add_option('--cpp-header-dir', dest='cppheaderdir', metavar='DIR',
                  help='input directory for C++ header files [required]')
parser.add_option('--capi-header-dir', dest='capiheaderdir', metavar='DIR',
                  help='output directory for C API header files')
parser.add_option('--cpptoc-global-impl', dest='cpptocglobalimpl', metavar='FILE',
                  help='input/output file for CppToC global translations')
parser.add_option('--ctocpp-global-impl', dest='ctocppglobalimpl', metavar='FILE',
                  help='input/output file for CppToC global translations')
parser.add_option('--cpptoc-dir', dest='cpptocdir', metavar='DIR',
                  help='input/output directory for CppToC class translations')
parser.add_option('--ctocpp-dir', dest='ctocppdir', metavar='DIR',
                  help='input/output directory for CppToC class translations')
parser.add_option('--gypi-file', dest='gypifile', metavar='FILE',
                  help='output file for path information')
parser.add_option('--no-cpptoc-header',
                  action='store_true', dest='nocpptocheader', default=False,
                  help='do not output the CppToC headers')
parser.add_option('--no-cpptoc-impl',
                  action='store_true', dest='nocpptocimpl', default=False,
                  help='do not output the CppToC implementations')
parser.add_option('--no-ctocpp-header',
                  action='store_true', dest='noctocppheader', default=False,
                  help='do not output the CToCpp headers')
parser.add_option('--no-ctocpp-impl',
                  action='store_true', dest='noctocppimpl', default=False,
                  help='do not output the CToCpp implementations')
parser.add_option('--no-backup',
                  action='store_true', dest='nobackup', default=False,
                  help='do not create a backup of modified files')
parser.add_option('-c', '--classes', dest='classes', action='append',
                  help='only translate the specified classes')
parser.add_option('-q', '--quiet',
                  action='store_true', dest='quiet', default=False,
                  help='do not output detailed status information')
(options, args) = parser.parse_args()

# the cppheader option is required
if options.cppheaderdir is None:
    parser.print_help(sys.stdout)
    sys.exit()

# make sure the header exists
if not path_exists(options.cppheaderdir):
    sys.stderr.write('File '+options.cppheaderdir+' does not exist.')
    sys.exit()

# create the header object
if not options.quiet:
    sys.stdout.write('Parsing C++ headers from '+options.cppheaderdir+'...\n')
header = obj_header()
header.add_directory(options.cppheaderdir)

writect = 0

if not options.capiheaderdir is None:
    #output the C API header
    if not options.quiet:
        sys.stdout.write('In C API header directory '+options.capiheaderdir+'...\n')
    filenames = sorted(header.get_file_names())
    for filename in filenames:
        if not options.quiet:
            sys.stdout.write('Generating '+filename+' C API header...\n')
        writect += write_capi_header(header,
                                     os.path.join(options.capiheaderdir, filename),
                                     not options.nobackup)
    
# build the list of classes to parse
allclasses = header.get_class_names()
if not options.classes is None:
    for cls in options.classes:
        if not cls in allclasses:
            sys.stderr.write('ERROR: Unknown class: '+cls)
            sys.exit()
    classes = options.classes
else:
    classes = allclasses

classes = sorted(classes)

if not options.cpptocglobalimpl is None:
    # output CppToC global file
    if not options.quiet:
        sys.stdout.write('Generating CppToC global implementation...\n')
    writect += write_cpptoc_impl(header, None, options.cpptocglobalimpl, \
                                 not options.nobackup)

if not options.ctocppglobalimpl is None:
    # output CToCpp global file
    if not options.quiet:
        sys.stdout.write('Generating CToCpp global implementation...\n')
    writect += write_ctocpp_impl(header, None, options.ctocppglobalimpl, \
                                 not options.nobackup)

if not options.cpptocdir is None:
    # output CppToC class files
    if not options.quiet:
        sys.stdout.write('In CppToC directory '+options.cpptocdir+'...\n')
    
    for cls in classes:
        if not options.nocpptocheader:
            if not options.quiet:
                sys.stdout.write('Generating '+cls+'CppToC class header...\n')
            writect += write_cpptoc_header(header, cls, options.cpptocdir,
                                           not options.nobackup)
        if not options.nocpptocimpl:
            if not options.quiet:
                sys.stdout.write('Generating '+cls+'CppToC class implementation...\n')
            writect += write_cpptoc_impl(header, cls, options.cpptocdir,
                                         not options.nobackup)

if not options.ctocppdir is None:
    # output CppToC class files
    if not options.quiet:
        sys.stdout.write('In CToCpp directory '+options.ctocppdir+'...\n')
    for cls in classes:
        if not options.nocpptocheader:
            if not options.quiet:
                sys.stdout.write('Generating '+cls+'CToCpp class header...\n')
            writect += write_ctocpp_header(header, cls, options.ctocppdir,
                                           not options.nobackup)
        if not options.nocpptocimpl:
            if not options.quiet:
                sys.stdout.write('Generating '+cls+'CToCpp class implementation...\n')
            writect += write_ctocpp_impl(header, cls, options.ctocppdir,
                                         not options.nobackup)

if not options.gypifile is None:
    # output the gypi file
    if not options.quiet:
        sys.stdout.write('Generating '+options.gypifile+' file...\n')
    writect += write_gypi_file(header, options.gypifile, not options.nobackup)

if not options.quiet:
    sys.stdout.write('Done - Wrote '+str(writect)+' files.\n')


