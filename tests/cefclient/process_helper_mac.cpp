#include "include/cef_app.h"
#include "cefclient/client_app.h"

int main(int argc, char* argv[]) {
  CefMainArgs main_args(argc, argv);
  CefRefPtr<CefApp> app(new ClientApp);
  return CefExecuteProcess(main_args, app); // Execute the secondary process.
}
