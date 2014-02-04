# Introduction

R is a language and environment for statistical computing and graphics. It is a [GNU project](http://www.gnu.org/) which is similar to the S language and environment which was developed at Bell Laboratories (formerly AT&T, now Lucent Technologies) by John Chambers and colleagues. R can be considered as a different implementation of S. There are some important differences, but much code written for S runs unaltered under R.

R provides a wide variety of statistical (linear and non-linear modeling, classical statistical tests, time-series analysis, classification, clustering, ...) and graphical techniques, and is highly extensible. The S language is often the vehicle of choice for research in statistical methodology, and R provides an Open Source route to participation in that activity.

(Text taken from [What is R?](http://www.r-project.org/about.html))

More information about R can be found at [r-project.org](http://www.r-project.org/).

<big><font color=blue> ⇢ This bundle requires a R version greater R 2.8.</font></big>

# Commands

## Run Selection/Document In R
<button>&nbsp;&#x2318;R&nbsp;</button>
It executes the current document or selection (if the selection only contains out-commented R code the current document) in a self-sufficient environment of the command-line version of R and it displays the output in an HTML window. By default new plots use the "pdf" device and are placed in a temporary folder and displayed at the end of the HTML window.

## Execute Selection/Document In R (Insert/Pasteboard/Tooltip)
<button>&nbsp;^&#x2318;R&nbsp;</button>
It executes the current document or selection in a self-sufficient environment of the command-line version of R. The output will be inserted, or will be copied into the pasteboard, or will be shown as Tooltip or.

## Send Selection/Document to Rdaemon
<button>&nbsp;&#x21E7;&#x2318;R&nbsp;</button>
It sends the current document or selection line by line to the Rdaemon. If Rdaemon is installed and it is not yet running it will start it, it opens the Rsession project, and the file `~/Library/Application Support/Rdaemon/console.Rcon` will contain the output.

***Hint*** To use that command you have to install the Rdaemon Bundle in beforehand.

## Send Selection/Document to R.app
<button>&nbsp;&#x2325;&#x21E7;&#x2318;R&nbsp;</button>
It executes the current document or selection in R.app and switches to R.app's Console.

***Hint*** To use that command you have to install R.app in beforehand.

## Send Selection/Document to R.app & Step
<button>&nbsp;&#x2325;&#x21E7;↩&nbsp;</button>
It executes the current line or selection in R.app and goes to the end of the next line. TextMate keeps its focus.

***Hint*** To use that command you have to install R.app in beforehand.

## Completion…
<button>&nbsp;^.&nbsp;</button>
Based on all installed packages and local function declarations within the current R script it shows an inline menu with completion suggestions for the current word or selection as <code style="background-color:lightgrey;color:black">&nbsp;function&nbsp;[library]&nbsp;</code> or as <code style="background-color:lightgrey;color:black">&nbsp;command&nbsp;…local…&nbsp;</code> indicating that `function` is defined within the current R script.

If the “Completion…” command is invoked from a running Rdaemon document the notation <code style="background-color:lightgrey;color:black">&nbsp;function&nbsp;{library}&nbsp;</code> indicates that the `library` is not loaded (or `function` is not found as valid function name in a loaded library) whereby the notation  <code style="background-color:lightgrey;color:black">&nbsp;function&nbsp;…library…&nbsp;</code> indicates that `library` is loaded.

As default it also displays an inline menu if there is only one suggestion found in order to give you an hint about the required library. You can force TextMate to complete it without displaying that menu by setting the TextMate shell variable `TM_R_AUTOCOMPLETE` to `1`.

***Hint*** This command works case-sensitively. E.g. if you type `math` (without selection and there is no command beginning with `math`) and invoke this command it lists all case-insensitive matched commands like `Math.fraction`, etc. as a tooltip caused by the chosen "Insert as Snippet" mechanism.

## Show R Help for actual Word/Selection
<button>&nbsp;^H&nbsp;</button>
It shows an HTML document with the found R help for the current word or of that command in which the caret is located. If no help file is found it opens an HTML window with all found keywords beginning with the current word. Furthermore this help window offers a `Search for` field to enter a new search term (a regular expression). The check box `Begins with` adds a `^` at the beginning of the search term. The search makes usage of the R command `help.search(TERM)`.

***Hint*** The search function `help.search` allows to look for the entered term case-sensitively by using the regular expression flag `(?-i)` e.g. to look exactly for `T` type `“(?-i)^T$”` whereby ^ means look only from the beginning of an help entry and $ means to look until the end of an help entry.
    
## Show Function Usage
<button>&nbsp;&#x2325;&#x21E7;H&nbsp;</button>
Based on all installed packages and local function declarations it shows a tooltip with the function signature for the current word &mdash; or that command in which the caret is located in respect of nested parentheses &mdash; or of the selection.

## Show Function Usage + Insert “(”
<button>&nbsp;(&nbsp;</button>
Based on all installed packages and local function declarations it shows a tooltip with the function signature for the current word and it inserts “()” or “(”.

***Hint*** This command will run in a background task to avoid waiting for unknown commands or if lots of packages are installed. This functionality can be switched off by deactivating the bound key equivalent within in the Bundle Editor.

## Function Parameter…
<button>&nbsp;^,&nbsp;</button>
It shows an inline menu with all available parameters and inserts a snippet with the chosen one(s). This command also tries to figure out whether it is necessary to insert a comma “, ”. If the inserted comma “, ” is set falsely one can press <button>&#x21E5;</button> twice to highlight it.

***Hint*** It is possible to write its own parameter list for given functions. These lists have to be saved in `~/Library/Application Support/TextMate/R/lib/command_args` and the file name represents exactly the function name. Invoke simply the command `“R” → “Documentation” → “Edit user-defined Function Parameter”` to edit those parameter lists.

See here an example for <a onclick="document.getElementById('plot').style.display=(document.getElementById('plot').style.display=='')?'none':''" href="#">`$TM_BUNDLE_SUPPORT/lib/command_args/plot`</a>:

<pre id="plot" style="display:none">
	asp="y/x aspect ratio"
	log="x|y|xy|yx"
	main="title"
	sub="subtitle"
	type="p|l|b|c|o|h|s|S|n"
	xlab="x-title"
	xlog=TRUE
	ylab="y-title"
	ylog=TRUE
</pre>

## “par()” Parameters…
<button>&nbsp;^;&nbsp;</button>
It shows an inline menu with all parameters defined in `$TM_BUNDLE_SUPPORT/lib/command_args/par` and inserts a snippet with the chosen one(s). This command also tries to figure out whether it is necessary to insert a comma “, ”. If the inserted comma “, ” is set falsely one can press <button>&#x21E5;</button> twice to highlight it.

## “require(xxx)” for current Function
<button>&nbsp;^&#x21E7;L&nbsp;</button>
It looks for that package in which the current keyword &mdash; "()" will be recognized &mdash; is defined, and it inserts the R code to load that package `require(PACKAGE)` above the current line.

## Prefix Package Name to current Function
<button>&nbsp;^&#x2325;&#x21E7;L&nbsp;</button>
It prefixes the current function with the found package name. Useful e.g. if a function occurs in more than one loaded package.

## Package Name…
<button>&nbsp;&#x2325;&#x21E7;&#x2318;L&nbsp;</button>
It shows all installed packages as an inline menu.

## Option List as Pull Down… / BoolToggler
<button>&nbsp;^F12&nbsp;</button>
This is an auxiliary tool command with these two different tasks based on a selection:

* It negates the logical value if the selection is "FALSE" or "TRUE" and "F" or "T" resp.
* It shows an inline menu of all values which are selected and delimited by "|" and replaces the selection by the chosen one.

  For instance this is useful after inserting the parameter `method` of the R function `dist`.<br>The selected value is:<br>
&nbsp;&nbsp;&nbsp;`euclidean|maximum|manhattan|canberra|binary|minkowski`

  or if the selected value (like for `par`, parameter `font.lab`) is:<br>
&nbsp;&nbsp;&nbsp;`1-plain|2-bold|3-italics|4-bolditalics`

  it only inserts the according digits.

## Create Vector/Matrix from Selection
<button>&nbsp;^&#x2325;C&nbsp;</button>
It inserts a vector in the form of `x <- c(x1, x2, ...)` resp. `x <- matrix(c(x1, x2, ...))` as snippet taken from a selected string or the current content of the clipboard. Delimiters are " ", "&#x21A9;", or "&#x21E5;". If an element doesn't consist of digits the element will be enclosed by double-quotes. It won't be checked for creating a matrix whether the length of the vector is a sub-multiple of the numbers of rows.

## Show File Header
If one only selects a file path this command shows you the first three lines of that file as tooltip. Useful for the import of data files to determine the its structure or whether the data file has an header or not etc.

## Next/Previous List Element/Parameter Value
<button>&nbsp;^&#x2325;&#x2192;&nbsp;</button><button>&nbsp;^&#x2325;&#x2190;&nbsp;</button>
It tries to highlight the next/previous element (if quoted only the content) of a list/vector or the value of function parameters.

## Tidy (removes all comments!)
<button>&nbsp;^&#x21E7;H&nbsp;</button>
It tidies the selection or the entire document by deparsing them on-the-fly using the command-line version of R. General syntax errors will be displayed as tooltip and the caret will be moved to the first error.
<font color=red><br><br>
<b>Attention:</b> All comments will be deleted!
</font><br><br>
***Hint*** This command can also be used as a kind of `Syntax Checker`. It only checks the R code for general syntax error like missing brackets, or commas, etc. It does **not** check for semantic errors like if a variable was assigned correctly or not.

## Function Call
<button>&nbsp;^&#x21E7;W&nbsp;</button>
It inserts: &nbsp;&nbsp;&nbsp;<code><span style="background-color:lightblue;color:black">sum</span>(SELECTION/WORD)</code> as snippet. The default function can be set via the shell variable `TM_R_WRAP_DEFAULT_FUNCTION`.

## Function Definition
<button>&nbsp;^&#x21E7;&#x2318;W&nbsp;</button>
It inserts:<br><pre>	x <- function(var) {
		SELECTION/WORD
	}
</pre> as snippet.

## Drag&amp;Drop Facilities
-   __load (*.Rdata)__

	If a `*.Rdata` or `*.Rda` file is drag&amp;dropped to a R/R console document it inserts:
	
	`load(FILE)`.
	
	By pressing SHIFT while dragging it inserts the absolute file path.

-   __source (*.R)__

	If a `*.R` file is drag&amp;dropped to a R/R console document it inserts:
	
	<code>source(FILE, chdir = <span style="background-color:lightblue;color:black">TRUE</span>)</code>.
	
	By pressing SHIFT while dragging it inserts the absolute file path.

-   __read.csv (*.csv)__

	If a `*.csv` file is drag&amp;dropped to a R/R console document it inserts:
	
	<code>read.csv(file = FILE, header = <span style="background-color:lightblue;color:black">TRUE</span>, stringsAsFactors = <span style="background-color:lightblue;color:black">FALSE</span>)</code>.
	
	By pressing SHIFT while dragging it inserts the absolute file path.

-   __read.table (*.tab)__

	If a `*.tab` file is drag&amp;dropped to a R/R console document it inserts:
	
	<code>read.table(file = FILE, sep = <span style="background-color:lightblue;color:black">\t</span>, header = <span style="background-color:lightblue;color:black">TRUE</span>, stringsAsFactors = <span style="background-color:lightblue;color:black">FALSE</span>)</code>.
	
	By pressing SHIFT while dragging it inserts the absolute file path.

# TextMate Shell Variables

## TM&#95;R&#95;AUTOCOMPLETE

As default TextMate displays an inline menu if there is only one suggestion found in order to give you an hint for the required library. You can force TextMate to complete it without displaying that menu by setting the shell variable `TM_R_AUTOCOMPLETE` to `1`. See also [Completion…](#sect_2.5).

## TM&#95;R&#95;WRAP&#95;DEFAULT&#95;FUNCTION

Set the default function for “Wrap Selection → Function Call” ^⇧W. If unset `sum` will be taken.

## TM&#95;R&#95;SHOW&#95;ALWAYS&#95;HELPSEARCH

As default `Show R Help for actual Word` opens a single window without a search field if the actual word matches one keyword. To avoid this set that shell variable to “1”.

## TM&#95;REXEC

If not set a R session will be invoked by <code>R --vanilla --slave --encoding=UTF-8</code> otherwise, if set e.g. to "R32", a R session will be invoked by <code>R32 --vanilla --slave --encoding=UTF-8</code> in order to be able to start R explicitly in 64 ("R64") or 32 ("R32") bit mode. In addition it also allows to add more command line arguments like "R32 --verbose" will execute <code>R32 --verbose --vanilla --slave --encoding=UTF-8</code>.

## TM&#95;RMATE&#95;OUTPUT&#95;FONT

Set the font of Rmate's output window. Default is set to “Monaco”.

## TM&#95;RMATE&#95;OUTPUT&#95;FONTSIZE

Set the font size of Rmate's output window. Default is set to “10”.

## TM&#95;RMATE&#95;ENABLE&#95;LINECOUNTER

For debugging large R scripts it could be useful to have the chance to use the outputted leading prompt <code>&gt;</code> as hyperlink to jump into the corresponding line of the R script. For that purpose you can set this shell variable to “1”. Please note that by enabling it the script **may not** contain multi-line string declarations, otherwise the string variables will be erroneous (these strings contain the internal string marker<code> #§*</code>).

# Troubleshooting &amp; FAQ

-   __`'re-encoding is not available on this system'` or `'object ".PSenv" not found'`__

    If you see one of these messages then you are most likely using an older version of R. In this case you should upgrade to the latest (currently, version 2.6.1) by downloading the pre-built universal R.app installer from <a href="http://www.r-project.org">r-project.org</a>.

-   __`115:116: syntax error: Expected end of line, etc. but found “. (-2741)`__

    If you see such an error (or similar) while sending something to "R.app" it is very likely that you are also running the "Rdaemon" with loaded "CarbonEL". Unfortunately "CarbonEL" uses the same application name "R", thus the AppleScript will send the R code to it, not to "R.app". In such a case you have to quit the Rdaemon.
    
-   __.../R.tmbundle/Support/lib/popen3.rb:18: warning: Insecure world writable dir "DIR"  in PATH, mode 040777__

    If Rmate is outputting this warning message it is very likely that "DIR" has write permissions set to **group** and **others**. To change the permission for that "DIR" run this command from a Terminal window:

    `chmod og-w 'DIR'`

-   __`Text strings defined as multi-line declarations inside a R script contain " #§*"`__

    Please disable TextMate's shell variable TM&#95;RMATE&#95;ENABLE&#95;LINECOUNTER.

# The bundle "R Console (Rdaemon)"

In addition there is the bundle "R Console (Rdaemon)" available. This bundle allows to run the command-line version of R ***inside*** TextMate. A normal document window, which is set to the language "R Console (Rdaemon)", serves as R console. More details within this bundle.  

# The bundle "R Console (R.app)"

In addition there is the bundle "R Console (R.app)" available. This bundle allows to remote the Mac OSX GUI "R.app". More details within this bundle.  

# Main Bundle Maintainer

***Date: Mar 07 2012***

<pre>
-  Hans-Jörg Bibiko&nbsp;&nbsp;<a href="mailto:bibiko@eva.mpg.de">bibiko@eva.mpg.de</a>
-  Charilaos Skiadas&nbsp;<a href="mailto:cskiadas@gmail.com">cskiadas@gmail.com</a>
</pre>

## Credits

Many thanks to 
<pre>
- John Purnell
- Balthasar Bickel
- Jon Claydon
- Berend Hasselman
</pre>

for all the valuable suggestions and the exhausting tests.
