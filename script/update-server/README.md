# Atom Update Test Server

This folder contains a simple implementation of Atom's update server to be used for testing the update process with local builds.

## How to use it

1. Since you probably want to try upgrading an installed Atom release to a newer version, start your shell and set the `ATOM_RELEASE_VERSION` environment var to the desired version:

   **Windows**
   ```
   set ATOM_RELEASE_VERSION="1.32.0-beta1"
   ```

   **macOS**
   ```
   export ATOM_RELEASE_VERSION="1.32.0-beta1"
   ```

2. Run a full build of Atom such that the necessary release artifacts are in the `out` folder:

   **Windows**
   ```
   script/build --create-windows-installer
   ```

   **macOS**
   ```
   script/build --compress-artifacts
   ```

3. Start up the server in this folder:

   ```
   npm install
   npm start
   ```

   **NOTE:** You can customize the port by setting the `PORT` environment variable.

4. Start Atom from the command line with the `ATOM_UPDATE_URL_PREFIX` environment variable set to `http://localhost:3456` (change this to reflect any `PORT` override you might have used)

5. Open the About page and try to update Atom.  The update server will write output to the console when requests are received.
