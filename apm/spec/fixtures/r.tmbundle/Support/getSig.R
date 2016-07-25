getSig <- function (..., snippet=T)
	sapply(unlist(list(...)), function(name, snipIdx=0, argIdx=0)
		paste(c(name, "(",
			if (snippet && is.null(formals(name)))
				"$1"
			else
				lapply(
					lapply(names(f <- formals(name)),
						function (arg)
							if (is.symbol(f[[arg]]) && f[[arg]] == "") arg else list(arg, f[[arg]])
					),
					function (arg, escape=function(x) ifelse(snippet, gsub(" *\n +", " ", gsub("([\\$`}])", "\\\\\\1", x)), x))
						if (is.list(arg))
							paste(if (snippet) paste("${", snipIdx <<- snipIdx + 1, ":", sep=""),
								ifelse((argIdx <<- argIdx + 1) > 1, ", ", ""),
								escape(deparse(as.name(arg[[1]]), backtick=T)),
								"=",
								if (snippet) paste("${", snipIdx <<- snipIdx + 1, ":", sep=""),
								if (is.character(arg[[2]]))
									paste('"',
										if (snippet) paste('${', snipIdx <<- snipIdx + 1, ":", sep=""),
										escape(substr(deparse(arg[[2]]), 2, nchar(deparse(arg[[2]]),type="c")-1)),
										ifelse(snippet, '}', ""),
										'"',
										sep=""
									)
								else
									escape(paste(deparse(arg[[2]], backtick=T, control="useSource"), collapse="\n"))
								,
								ifelse(snippet, "}}", ""),
								sep="")
						else
							paste(ifelse((argIdx <<- argIdx + 1) > 1,
									ifelse(snippet, paste("${", snipIdx <<- snipIdx + 1, ":, ", sep=""), ", "),
									""),
								if (snippet) paste("${", snipIdx <<- snipIdx + 1, ":", sep=""),
								escape(arg),
								ifelse(snippet, ifelse(argIdx > 1, "}}", "}"), ""),
								sep="")
				)
			,
			")")
			, collapse=""
		)
	)
