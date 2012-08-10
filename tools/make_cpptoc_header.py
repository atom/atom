# Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
# reserved. Use of this source code is governed by a BSD-style license that
# can be found in the LICENSE file.

from cef_parser import *

def make_cpptoc_header(header, clsname):
    cls = header.get_class(clsname)
    if cls is None:
        raise Exception('Class does not exist: '+clsname)
    
    dllside = cls.is_library_side()
    defname = string.upper(get_capi_name(clsname[3:], False))
    capiname = cls.get_capi_name()
    
    result = get_copyright()

    result += '#ifndef CEF_LIBCEF_DLL_CPPTOC_'+defname+'_CPPTOC_H_\n'+ \
              '#define CEF_LIBCEF_DLL_CPPTOC_'+defname+'_CPPTOC_H_\n' + \
              '#pragma once\n'
    
    if dllside:
        result += """
#ifndef BUILDING_CEF_SHARED
#pragma message("Warning: "__FILE__" may be accessed DLL-side only")
#else  // BUILDING_CEF_SHARED
"""
    else:
        result += """
#ifndef USING_CEF_SHARED
#pragma message("Warning: "__FILE__" may be accessed wrapper-side only")
#else  // USING_CEF_SHARED
"""

    # include the headers for this class
    result += '\n#include "include/'+cls.get_file_name()+'"\n' \
              '#include "include/capi/'+cls.get_capi_file_name()+'"\n'

    # include headers for any forward declared classes that are not in the same file
    declares = cls.get_forward_declares()
    for declare in declares:
        dcls = header.get_class(declare)
        if dcls.get_file_name() != cls.get_file_name():
              result += '#include "include/'+dcls.get_file_name()+'"\n' \
                        '#include "include/capi/'+dcls.get_capi_file_name()+'"\n'

    result += """#include "libcef_dll/cpptoc/cpptoc.h"

// Wrap a C++ class with a C structure.
"""

    if dllside:
        result += '// This class may be instantiated and accessed DLL-side only.\n'
    else:
        result += '// This class may be instantiated and accessed wrapper-side only.\n'
    
    result +=  'class '+clsname+'CppToC\n'+ \
               '    : public CefCppToC<'+clsname+'CppToC, '+clsname+', '+capiname+'> {\n'+ \
               ' public:\n'+ \
               '  explicit '+clsname+'CppToC('+clsname+'* cls);\n'+ \
               '  virtual ~'+clsname+'CppToC() {}\n'+ \
               '};\n\n'
    
    if dllside:
        result += '#endif  // BUILDING_CEF_SHARED\n'
    else:
        result += '#endif  // USING_CEF_SHARED\n'
    
    result += '#endif  // CEF_LIBCEF_DLL_CPPTOC_'+defname+'_CPPTOC_H_\n'
    
    return wrap_code(result)


def write_cpptoc_header(header, clsname, dir, backup):
    file = dir+os.sep+get_capi_name(clsname[3:], False)+'_cpptoc.h'
    
    if path_exists(file):
        oldcontents = read_file(file)
    else:
        oldcontents = ''
    
    newcontents = make_cpptoc_header(header, clsname)
    if newcontents != oldcontents:
        if backup and oldcontents != '':
            backup_file(file)
        write_file(file, newcontents)
        return True
    
    return False


# test the module
if __name__ == "__main__":
    import sys
    
    # verify that the correct number of command-line arguments are provided
    if len(sys.argv) < 3:
        sys.stderr.write('Usage: '+sys.argv[0]+' <infile> <classname>')
        sys.exit()
        
    # create the header object
    header = obj_header()
    header.add_file(sys.argv[1])
    
    # dump the result to stdout
    sys.stdout.write(make_cpptoc_header(header, sys.argv[2]))
