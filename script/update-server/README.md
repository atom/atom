# Atom Update Test Server

This folder contains a simple implementation of Atom's update server to be used for testing the update process with local builds.

## Prerequisites

On macOS, you will need to configure a "Mac Development" certificate for your local machine so that the `script/build --test-sign` parameter will work.  Here are the steps to set one up:

1. Install Xcode if it isn't already
1. Launch Xcode and open the Preferences dialog (<kbd>Cmd + ,</kbd>)
1. Switch to the Accounts tab
1. If you don't already see your Apple account in the leftmost column, click the `+` button at the bottom left of the window, select "Apple ID" and then click Continue.  Sign in with your Apple account and then you'll be sent back to the Accounts tab.
1. Click the "Manage Certificates..." button in the lower right of the Accounts page
1. Click the `+` button in the lower left of the Signing Certificates popup and then select "Mac Development"
1. A new certificate should now be in the list of the Signing Certificates window with the name of your macOS machine.  Click "Done"
1. In a Terminal, verify that your Mac Development certificate is set up by running

  ```
  security find-certificate -c 'Mac Developer'
  ```

  If it returns a lot of information with "Mac Developer: your@apple-id-email.com" inside of it, your certificate is configured correctly and you're now ready to run an Atom build with the `--test-sign` parameter.

## How to use it

1. Since you probably want to try upgrading an installed Atom release to a newer version, start your shell and set the `ATOM_RELEASE_VERSION` environment var to the version that you want the server to advertise as the latest version:

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
   script/build --compress-artifacts --test-sign
   ```

3. Start up the server in this folder:

   ```
   npm install
   npm start
   ```

   **NOTE:** You can customize the port by setting the `PORT` environment variable.

4. Start Atom from the command line with the `ATOM_UPDATE_URL_PREFIX` environment variable set to `http://localhost:3456` (change this to reflect any `PORT` override you might have used)

5. Open the About page and try to update Atom.  The update server will write output to the console when requests are received.
