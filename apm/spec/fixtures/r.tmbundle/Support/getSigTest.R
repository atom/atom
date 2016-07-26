# This file is just used for testing getSig.R
# I committed it to the repo so it can be used for further maintenance of getSig.R
#
# Kevin Ballard

source("./getSig.R")

# function to use in testing symbols
fubar <- function (x, y=`+`, z=if (T) "foo" else "bar", q="haha", `a a`=c("heavy", "medium", "light"), meth=mean) {
	do.call(y, as.list(x))
}

# cat(paste(getSig(if ('p' %in% (ary <- sort(apropos('^p', mode='function')))) 'p' else ary), collapse='\n'))
cat(paste(getSig("fubar"), collapse="\n"))
