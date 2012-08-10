Chromium Embedded Framework (CEF) Binary Distribution
-------------------------------------------------------------------------------

Date:             $DATE$

CEF Version:      $CEF_VER$
CEF URL:          $CEF_URL$@$CEF_REV$

Chromium Verison: $CHROMIUM_VER$
Chromium URL:     $CHROMIUM_URL$@$CHROMIUM_REV$


This distribution contains all components necessary to build and distribute an
application using CEF. Please see the LICENSING section of this document for
licensing terms and conditions.


CONTENTS
--------

cefclient   Contains the cefclient sample application configured to build
            using the files in this distribution.

Debug       Contains libcef.so and other components required to run the debug
            version of CEF-based applications.

docs        Contains C++ API documentation generated from the CEF header files.

include     Contains all required CEF header files.

libcef_dll  Contains the source code for the libcef_dll_wrapper static library
            that all applications using the CEF C++ API must link against.

Release     Contains libcef.so and other components required to run the
            release version of CEF-based applications.


USAGE
-----

Run 'make -j4 cefclient BUILDTYPE=Debug' to build the cefclient target in
Debug mode.

Please visit the CEF Website for additional usage information.

http://code.google.com/p/chromiumembedded


REDISTRIBUTION
--------------

This binary distribution contains the below components. Components listed under
the "required" section must be redistributed with all applications using CEF.
Components listed under the "optional" section may be excluded if the related
features will not be used.

Required components:

* CEF core library
    libcef.so

Optional components:

* Localized resources
    locales/
  Note: Contains localized strings for WebKit UI controls. A .pak file is loaded
  from this folder based on the value of environment variables which are read
  with the following precedence order: LANGUAGE, LC_ALL, LC_MESSAGES and LANG.
  Only configured locales need to be distributed. If no locale is configured the
  default locale of "en-US" will be used. Locale file loading can be disabled
  completely using CefSettings.pack_loading_disabled. The locales folder path
  can be customized using CefSettings.locales_dir_path.

* Other resources
    cef.pak
  Note: Contains WebKit image and inspector resources. Pack file loading can be
  disabled completely using CefSettings.pack_loading_disabled. The cef.pak file
  path can be customized using CefSettings.pack_file_path.


LICENSING
---------

The CEF project is BSD licensed. Please read the LICENSE.txt file included with
this binary distribution for licensing terms and conditions. Other software
included in this distribution is provided under other licenses. Please visit the
below link for complete Chromium and third-party licensing information.

http://code.google.com/chromium/terms.html 
