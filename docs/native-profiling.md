# Profiling the Atom Render Process on macOS with Instruments

![Instruments](https://cloud.githubusercontent.com/assets/1789/14193295/d503db7a-f760-11e5-88bf-fe417c0cd913.png)

* Determine the version of Electron for your version of Atom.
  * Open the dev tools with `alt-cmd-i`
  * Evaluate `process.versions.electron` in the console.
* Based on this version, download the appropriate Electron symbols from the [releases](https://github.com/atom/electron/releases) page.
  * The file name should look like `electron-v1.X.Y-darwin-x64-dsym.zip`.
  * Decompress these symbols in your `~/Downloads` directory.
* Now create a time profile in Instruments.
  * Open `Instruments.app`.
  * Select `Time Profiler`
  * In Atom, determine the pid to attach to by evaluating `process.pid` in the dev tools console.
  * Attach to this pid via the menu at the upper left corner of the Instruments profiler.
  * Click record, do your thing.
  * Click stop.
  * The symbols should have been automatically located by Instruments (via Spotlight or something?), giving you a readable profile.
