python ~/code/gyp/gyp --depth=. atom.gyp && xcodebuild -project atom.xcodeproj/ -configuration Debug -target Atom clean build && open build/Default/Atom.app
