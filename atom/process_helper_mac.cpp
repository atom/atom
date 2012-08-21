#include "include/cef_app.h"

int main(int argc, char* argv[]) {
  CefMainArgs main_args(argc, argv);
  CefRefPtr<CefApp> app;
  return CefExecuteProcess(main_args, app); // Execute the secondary process.
}
