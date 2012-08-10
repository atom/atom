@echo off
setlocal

if "%1"=="" (
set CPPDOC_EXE="C:\Program Files (x86)\richfeit\CppDoc\CppDoc.exe"
set CPPDOC_REV="XXX"
) else (
set CPPDOC_EXE="C:\Program Files (x86)\richfeit\CppDoc\cppdoc_cmd.exe"
set CPPDOC_REV="%1"
)

if not exist %CPPDOC_EXE% (
echo ERROR: Please install CppDoc from http://www.cppdoc.com/
) else (
%CPPDOC_EXE% -overwrite -title="CEF3 C++ API Docs - Revision %CPPDOC_REV%"  -footer="<center><a href="http://code.google.com/p/chromiumembedded" target="_top">Chromium Embedded Framework (CEF)</a> Copyright &copy 2012 Marshall A. Greenblatt</center>" -namespace-as-project -comment-format="///;//;///" -classdir=projects -module="cppdoc-standard" -extensions=h -languages="c=cpp,cc=cpp,cpp=cpp,cs=csharp,cxx=cpp,h=cpp,hpp=cpp,hxx=cpp,java=java" -D"OS_WIN" -D"USING_CEF_SHARED" -D"__cplusplus" -D"CEF_STRING_TYPE_UTF16" -enable-author=false -enable-deprecations=true -enable-since=true -enable-version=false -file-links-for-globals=false -generate-deprecations-list=false -generate-hierarchy=true -header-background-dark="#ccccff" -header-background-light="#eeeeff" -include-private=false -include-protected=true -index-file-base=index -overview-html=overview.html -reduce-summary-font=true -selected-text-background=navy -selected-text-foreground=white -separate-index-pages=false -show-cppdoc-version=false -show-timestamp=false -summary-html=project.html -suppress-details=false -suppress-frames-links=false -table-background=white -wrap-long-lines=false ..\include #cef_runnable.h #cef_tuple.h #capi "..\docs\index.html"
)

endlocal