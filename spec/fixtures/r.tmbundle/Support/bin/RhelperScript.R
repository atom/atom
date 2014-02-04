TM_RdaemongetHelpURL <- function(x,...) {
	if(getRversion()>='2.10.0') {
		a<-gsub(".*/library/(.*?)/.*?/(.*?)(\\.html|$)",paste("http://127.0.0.1:",ifelse(tools:::httpdPort<1,tools::startDynamicHelp(T),tools:::httpdPort),"/library/\\1/html/\\2.html",sep=""),as.vector(help(x,try.all.packages=T,...)),perl=T)
		ifelse(length(a),cat(a,sep='\n'),cat("NA",sep=''))
	} else {
		a<-gsub("(.*?)/library/(.*?)/.*?/(.*?)(\\.html|$)","\\1/library/\\2/html/\\3.html",as.vector(help(x,try.all.packages=T,...)),perl=T)
		ifelse(length(a),cat(a,sep='\n'),cat("NA",sep=''))
	}
}

TM_RdaemongetHttpPort <- function() cat(ifelse(getRversion()>='2.10.0',ifelse(tools:::httpdPort<1,tools::startDynamicHelp(T),tools:::httpdPort),-2))
TM_RdaemongetSearchHelp <- function(x,ic=T) {
	if (getRversion()>='2.10.0') {
		p<-ifelse(tools:::httpdPort<1,tools::startDynamicHelp(T),tools:::httpdPort)
		a<-help.search(x,ignore.case=ic)[[4]][,c(3,1)]
		if(length(a)>0){
			if(is.null(dim(a))) {a<-matrix(a,ncol=2)}
			cat(sort(apply(a,1,function(x) {
				h<-gsub(".*/library/(.*?)/.*?/(.*?)(\\.html|$)",paste("http://127.0.0.1:",p,"/library/\\1/html/\\2.html",sep=""),help(x[2],package=x[1])[1],perl=T)
				paste(c(x[1],x[2],h),collapse='\t')})),sep='\n')
		} else {
			cat("NA",sep='')
		}
	} else {
		a<-help.search(x,ignore.case=ic)[[4]][,c(3,1)]
		if(length(a)>0){
			if(is.null(dim(a))) {a<-matrix(a,ncol=2)}
			cat(sort(apply(a,1,function(x) {
				h<-gsub("(.*?)/library/(.*?)/.*?/(.*?)(\\.html|$)","\\1/library/\\2/html/\\3.html",help(x[2],package=x[1])[1],perl=T)
				paste(c(x[1],x[2],h),collapse='\t')})),sep='\n')
		} else {
			cat("NA",sep='')
		}
	}
}
TM_RdaemongetInstalledPackages <- function() cat(installed.packages()[,1],sep='\n')
TM_RdaemongetLoadedPackages <- function() cat(sort(.packages()),sep='\n')
TM_RdaemongetPackageFor <- function(x) cat(help.search(paste("^",x,"$",sep=""),ignore.case=F)[[4]][,3],sep='\n')
TM_RdaemongetCompletionList <- function(x,ic=F) {
	invisible(help.search("^§!#%$"));db<-utils:::.hsearch_db()
	a<-db$Alias[grep(paste("^",x,sep=""),db$Alias[,1],ignore.case=ic,perl=T),c(1,3)]
	if(is.null(dim(a))) {a<-matrix(a,ncol=2)}
	a<-a[grep("[<,]|-(class|package|method(s)?)|TM_Rdaemon",a[,1],invert=T),]
	if(is.null(dim(a))) {a<-matrix(a,ncol=2)}
	cat(sort(apply(a,1,function(x)paste(c(x[1],x[2]),collapse='\t'))),sep='\n')
}
