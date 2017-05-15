## What we need to do

1. Strip extra files from release (`*.pdb, *.obj, *.lib, vendor\squirrel-win`)
1. Copy in `Updater.exe` and `AppSetup.exe` (and 7Zip)
1. Use `AppSetup.exe` to 7Zip `resources`
1. Render `atom.nuspec` using information from `package.json` (like Version
   number)
1. NuGet pack the `atom.nuspec` file
1. Create a dummy packages directory under atom-build
1. Create-Release.ps1
