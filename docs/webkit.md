* Get webkit source (~30 minutes)
  `git clone --depth 1 https://github.com/WebKit/webkit.git`
	`cd webkit`

* Apply tmm1's patch (found at end of this document)
	`patch -p1 < tmm1.patch`

* Build webkit (~2 hours, don't let your computer go to sleep)
	`Tools/Scripts/build-webkit --release`

* Copy WebKit.framework, WebCore.framework and JavaScript.framework from `webkit/WebKitBuild/Release` to
`atom/frameworks`

* Fix the dynamic library linking problems
  `rake webkit-fix`

# tmm1's patch
```
Corey needs to go on the mini server and create the patch based on tmm1's changes
```
