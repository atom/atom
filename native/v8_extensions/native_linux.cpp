#include "native_linux.h"
#include "include/cef_base.h"
#include "include/cef_runnable.h"
#include "io_utils.h"
#include <iostream>
#include <fstream>
#include <sstream>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <vector>
#include <gtk/gtk.h>
#include <sys/inotify.h>
#include <pthread.h>
#include <openssl/evp.h>

#define BUFFER_SIZE 8192

using namespace std;

namespace v8_extensions {

void *NotifyWatchersCallback(void* pointer) {
  NativeHandler* handler = (NativeHandler*) pointer;
  handler->NotifyWatchers();
  return NULL;
}

void ExecuteWatchCallback(NotifyContext notifyContext) {
  map<string, CallbackContext> callbacks =
      notifyContext.callbacks[notifyContext.descriptor];
  map<string, CallbackContext>::iterator callback;
  for (callback = callbacks.begin(); callback != callbacks.end(); callback++) {
    CallbackContext callbackContext = callback->second;
    CefRefPtr<CefV8Context> context = callbackContext.context;
    CefRefPtr<CefV8Value> function = callbackContext.function;

    context->Enter();

    CefV8ValueList args;
    CefRefPtr<CefV8Value> retval;
    CefRefPtr<CefV8Exception> e;
    args.push_back(callbackContext.eventTypes);
    function->ExecuteFunction(retval, args);

    context->Exit();
  }
}

NativeHandler::NativeHandler() :
    CefV8Handler() {
  string nativePath = io_utils_real_app_path("/native/v8_extensions/native.js");
  if (!nativePath.empty()) {
    string extensionCode;
    if (io_utils_read(nativePath, &extensionCode) > 0)
      CefRegisterExtension("v8/native", extensionCode, this);
  }

  notifyFd = inotify_init();
  if (notifyFd != -1)
    g_thread_create_full(NotifyWatchersCallback, this, 0, true, false,
        G_THREAD_PRIORITY_NORMAL, NULL);
}

void NativeHandler::NotifyWatchers() {
  char buffer[BUFFER_SIZE];
  ssize_t bufferRead;
  size_t eventSize;
  ssize_t bufferIndex;
  struct inotify_event *event;
  bufferRead = read(notifyFd, buffer, BUFFER_SIZE);
  while (bufferRead > 0) {
    bufferIndex = 0;
    while (bufferIndex < bufferRead) {
      event = (struct inotify_event *) &buffer[bufferIndex];
      eventSize = offsetof (struct inotify_event, name) + event->len;

      NotifyContext context;
      context.descriptor = event->wd;
      context.callbacks = pathCallbacks;
      CefPostTask(TID_UI,
          NewCefRunnableFunction(&ExecuteWatchCallback, context));

      bufferIndex += eventSize;
    }
    bufferRead = read(notifyFd, buffer, BUFFER_SIZE);
  }
}

void NativeHandler::Exists(const CefString& name, CefRefPtr<CefV8Value> object,
    const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
    CefString& exception) {
  string path = arguments[0]->GetStringValue().ToString();
  struct stat statInfo;
  int result = stat(path.c_str(), &statInfo);
  retval = CefV8Value::CreateBool(result == 0);
}

void NativeHandler::Read(const CefString& name, CefRefPtr<CefV8Value> object,
    const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
    CefString& exception) {
  string path = arguments[0]->GetStringValue().ToString();
  string value;
  io_utils_read(path, &value);
  retval = CefV8Value::CreateString(value);
}

void NativeHandler::Absolute(const CefString& name,
    CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments,
    CefRefPtr<CefV8Value>& retval, CefString& exception) {
  string path = arguments[0]->GetStringValue().ToString();
  string relativePath;
  if (path[0] != '~')
    relativePath.append(path);
  else {
    relativePath.append(getenv("HOME"));
    relativePath.append(path, 1, path.length() - 1);
  }

  vector < string > segments;
  char allSegments[relativePath.length() + 1];
  strcpy(allSegments, relativePath.c_str());
  const char* segment;
  for (segment = strtok(allSegments, "/"); segment;
      segment = strtok(NULL, "/")) {
    if (strcmp(segment, ".") == 0)
      continue;
    if (strcmp(segment, "..") == 0) {
      if (segments.empty()) {
        retval = CefV8Value::CreateString("/");
        return;
      }
      segments.pop_back();
    } else
      segments.push_back(segment);
  }

  string absolutePath;
  unsigned int i;
  for (i = 0; i < segments.size(); i++) {
    absolutePath.append("/");
    absolutePath.append(segments.at(i));
  }
  retval = CefV8Value::CreateString(absolutePath);
}

void ListDirectory(string path, vector<string>* paths, bool recursive) {
  dirent **children;
  int childrenCount = scandir(path.c_str(), &children, 0, alphasort);
  struct stat statInfo;
  int result;

  for (int i = 0; i < childrenCount; i++) {
    if (strcmp(children[i]->d_name, ".") == 0
        || strcmp(children[i]->d_name, "..") == 0) {
      free(children[i]);
      continue;
    }
    string entryPath(path + "/" + children[i]->d_name);
    paths->push_back(entryPath);
    if (recursive) {
      result = stat(entryPath.c_str(), &statInfo);
      if (result == 0 && S_ISDIR(statInfo.st_mode))
        ListDirectory(entryPath, paths, recursive);
    }
    free(children[i]);
  }
  free(children);
}

void DeleteContents(string path) {
  dirent **children;
  const char* dirPath = path.c_str();
  int childrenCount = scandir(dirPath, &children, 0, alphasort);
  struct stat statInfo;

  for (int i = 0; i < childrenCount; i++) {
    if (strcmp(children[i]->d_name, ".") == 0
        || strcmp(children[i]->d_name, "..") == 0) {
      free(children[i]);
      continue;
    }

    string entryPath(path + "/" + children[i]->d_name);
    if (stat(entryPath.c_str(), &statInfo) != 0) {
      free(children[i]);
      continue;
    }

    if (S_ISDIR(statInfo.st_mode))
      DeleteContents(entryPath);
    else if (S_ISREG(statInfo.st_mode))
      remove(entryPath.c_str());
  }
  free(children);
  rmdir(dirPath);
}

void NativeHandler::List(const CefString& name, CefRefPtr<CefV8Value> object,
    const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
    CefString& exception) {
  string path = arguments[0]->GetStringValue().ToString();
  bool recursive = arguments[1]->GetBoolValue();
  vector < string > *paths = new vector<string>;
  ListDirectory(path, paths, recursive);

  retval = CefV8Value::CreateArray(paths->size());
  for (uint i = 0; i < paths->size(); i++)
    retval->SetValue(i, CefV8Value::CreateString(paths->at(i)));
  free (paths);
}

void NativeHandler::IsFile(const CefString& name, CefRefPtr<CefV8Value> object,
    const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
    CefString& exception) {
  string path = arguments[0]->GetStringValue().ToString();
  struct stat statInfo;
  int result = stat(path.c_str(), &statInfo);
  retval = CefV8Value::CreateBool(result == 0 && S_ISREG(statInfo.st_mode));
}

void NativeHandler::IsDirectory(const CefString& name,
    CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments,
    CefRefPtr<CefV8Value>& retval, CefString& exception) {
  string path = arguments[0]->GetStringValue().ToString();
  struct stat statInfo;
  int result = stat(path.c_str(), &statInfo);
  retval = CefV8Value::CreateBool(result == 0 && S_ISDIR(statInfo.st_mode));
}

void NativeHandler::OpenDialog(const CefString& name,
    CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments,
    CefRefPtr<CefV8Value>& retval, CefString& exception) {
  GtkWidget *dialog;
  dialog = gtk_file_chooser_dialog_new("Open File", GTK_WINDOW(window),
      GTK_FILE_CHOOSER_ACTION_OPEN, GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL,
      GTK_STOCK_OPEN, GTK_RESPONSE_ACCEPT, NULL);
  if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
    char *filename;
    filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
    retval = CefV8Value::CreateString(filename);
    g_free(filename);
  } else
    retval = CefV8Value::CreateNull();

  gtk_widget_destroy(dialog);
}

void NativeHandler::Open(const CefString& name, CefRefPtr<CefV8Value> object,
    const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
    CefString& exception) {
  path = arguments[0]->GetStringValue().ToString();
  CefV8Context::GetCurrentContext()->GetBrowser()->Reload();
}

void NativeHandler::Write(const CefString& name, CefRefPtr<CefV8Value> object,
    const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
    CefString& exception) {
  string path = arguments[0]->GetStringValue().ToString();
  string content = arguments[1]->GetStringValue().ToString();

  ofstream file;
  file.open(path.c_str());
  file << content;
  file.close();
}

void NativeHandler::WriteToPasteboard(const CefString& name,
    CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments,
    CefRefPtr<CefV8Value>& retval, CefString& exception) {
  string content = arguments[0]->GetStringValue().ToString();
  GtkClipboard* clipboard = gtk_clipboard_get_for_display(
      gdk_display_get_default(), GDK_NONE);
  gtk_clipboard_set_text(clipboard, content.c_str(), content.length());
  gtk_clipboard_store(clipboard);
}

void NativeHandler::ReadFromPasteboard(const CefString& name,
    CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments,
    CefRefPtr<CefV8Value>& retval, CefString& exception) {
  GtkClipboard* clipboard = gtk_clipboard_get_for_display(
      gdk_display_get_default(), GDK_NONE);
  char* content = gtk_clipboard_wait_for_text(clipboard);
  retval = CefV8Value::CreateString(content);
}

void NativeHandler::AsyncList(const CefString& name,
    CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments,
    CefRefPtr<CefV8Value>& retval, CefString& exception) {
  string path = arguments[0]->GetStringValue().ToString();
  bool recursive = arguments[1]->GetBoolValue();
  vector < string > *paths = new vector<string>;
  ListDirectory(path, paths, recursive);

  CefRefPtr<CefV8Value> callbackPaths = CefV8Value::CreateArray(paths->size());
  for (uint i = 0; i < paths->size(); i++)
    callbackPaths->SetValue(i, CefV8Value::CreateString(paths->at(i)));
  CefV8ValueList args;
  args.push_back(callbackPaths);
  CefRefPtr<CefV8Exception> e;
  arguments[2]->ExecuteFunction(retval, args);
  if (e)
    exception = e->GetMessage();
  free (paths);
}

void NativeHandler::MakeDirectory(const CefString& name,
    CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments,
    CefRefPtr<CefV8Value>& retval, CefString& exception) {
  string content = arguments[0]->GetStringValue().ToString();
  mkdir(content.c_str(), S_IRWXU);
}

void NativeHandler::Move(const CefString& name, CefRefPtr<CefV8Value> object,
    const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
    CefString& exception) {
  string from = arguments[0]->GetStringValue().ToString();
  string to = arguments[1]->GetStringValue().ToString();
  rename(from.c_str(), to.c_str());
}

void NativeHandler::Remove(const CefString& name, CefRefPtr<CefV8Value> object,
    const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
    CefString& exception) {
  string pathArgument = arguments[0]->GetStringValue().ToString();
  const char* path = pathArgument.c_str();

  struct stat statInfo;
  if (stat(path, &statInfo) != 0)
    return;

  if (S_ISREG(statInfo.st_mode))
    remove(path);
  else if (S_ISDIR(statInfo.st_mode))
    DeleteContents(pathArgument);
}

void NativeHandler::Alert(const CefString& name, CefRefPtr<CefV8Value> object,
    const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
    CefString& exception) {
  CefRefPtr<CefV8Value> buttonNamesAndCallbacks;
  if (arguments.size() < 3)
    buttonNamesAndCallbacks = CefV8Value::CreateArray(0);
  else
    buttonNamesAndCallbacks = arguments[2];

  GtkWidget *dialog;
  dialog = gtk_dialog_new_with_buttons("atom", GTK_WINDOW(window),
      GTK_DIALOG_DESTROY_WITH_PARENT, NULL);
  for (int i = 0; i < buttonNamesAndCallbacks->GetArrayLength(); i++) {
    string title =
        buttonNamesAndCallbacks->GetValue(i)->GetValue(0)->GetStringValue().ToString();
    gtk_dialog_add_button(GTK_DIALOG(dialog), title.c_str(), i);
  }
  gtk_window_set_modal(GTK_WINDOW(dialog), TRUE);

  string dialogMessage(arguments[0]->GetStringValue().ToString());
  dialogMessage.append("\n\n");
  dialogMessage.append(arguments[1]->GetStringValue().ToString());
  GtkWidget *label;
  label = gtk_label_new(dialogMessage.c_str());

  GtkWidget *contentArea;
  contentArea = gtk_dialog_get_content_area(GTK_DIALOG(dialog));
  gtk_container_add(GTK_CONTAINER(contentArea), label);

  gtk_widget_show_all(dialog);
  int result = gtk_dialog_run(GTK_DIALOG(dialog));
  if (result >= 0) {
    CefRefPtr<CefV8Value> callback =
        buttonNamesAndCallbacks->GetValue(result)->GetValue(1);
    CefV8ValueList args;
    CefRefPtr<CefV8Exception> e;
    callback->ExecuteFunction(retval, args);
    if (e)
      exception = e->GetMessage();
  }
  gtk_widget_destroy(dialog);
}

void NativeHandler::WatchPath(const CefString& name,
    CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments,
    CefRefPtr<CefV8Value>& retval, CefString& exception) {
  string path = arguments[0]->GetStringValue().ToString();
  int descriptor = inotify_add_watch(notifyFd, path.c_str(),
      IN_ALL_EVENTS & ~(IN_CLOSE | IN_OPEN | IN_ACCESS));
  if (descriptor == -1)
    return;

  CallbackContext callbackContext;
  callbackContext.context = CefV8Context::GetCurrentContext();
  callbackContext.function = arguments[1];
  CefRefPtr<CefV8Value> eventTypes = CefV8Value::CreateObject(NULL);
  eventTypes->SetValue("modified", CefV8Value::CreateBool(true),
      V8_PROPERTY_ATTRIBUTE_NONE);
  callbackContext.eventTypes = eventTypes;

  stringstream idStream;
  idStream << "counter";
  idStream << idCounter;
  string id = idStream.str();
  idCounter++;
  pathDescriptors[path] = descriptor;
  pathCallbacks[descriptor][id] = callbackContext;
  retval = CefV8Value::CreateString(id);
}

void NativeHandler::UnwatchPath(const CefString& name,
    CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments,
    CefRefPtr<CefV8Value>& retval, CefString& exception) {
  string path = arguments[0]->GetStringValue().ToString();

  int descriptor = pathDescriptors[path];
  if (descriptor == -1)
    return;

  map<string, CallbackContext> callbacks = pathCallbacks[descriptor];
  string id = arguments[1]->GetStringValue().ToString();
  callbacks.erase(id);
  if (callbacks.empty())
    inotify_rm_watch(notifyFd, descriptor);
}

void NativeHandler::Digest(const CefString& name, CefRefPtr<CefV8Value> object,
    const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
    CefString& exception) {
  string path = arguments[0]->GetStringValue().ToString();

  int fd = open(path.c_str(), O_RDONLY);
  if (fd < 0)
    return;

  const EVP_MD *md;
  OpenSSL_add_all_digests();
  md = EVP_get_digestbyname("md5");
  if (!md)
    return;

  EVP_MD_CTX context;
  EVP_MD_CTX_init(&context);
  EVP_DigestInit_ex(&context, md, NULL);

  char buffer[BUFFER_SIZE];
  int r;
  while ((r = read(fd, buffer, sizeof buffer)) > 0)
    EVP_DigestUpdate(&context, buffer, r);
  close(fd);

  unsigned char value[EVP_MAX_MD_SIZE];
  unsigned int length;
  EVP_DigestFinal_ex(&context, value, &length);
  EVP_MD_CTX_cleanup(&context);

  stringstream md5;
  char hex[3];
  for (uint i = 0; i < length; i++) {
    sprintf(hex, "%02x", value[i]);
    md5 << hex;
  }
  retval = CefV8Value::CreateString(md5.str());
}

void NativeHandler::LastModified(const CefString& name,
    CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments,
    CefRefPtr<CefV8Value>& retval, CefString& exception) {
  string path = arguments[0]->GetStringValue().ToString();
  struct stat statInfo;
  if (stat(path.c_str(), &statInfo) == 0) {
    CefTime time(statInfo.st_mtime);
    retval = CefV8Value::CreateDate(time);
  }
}

bool NativeHandler::Execute(const CefString& name, CefRefPtr<CefV8Value> object,
    const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
    CefString& exception) {
  if (name == "exists")
    Exists(name, object, arguments, retval, exception);
  else if (name == "read")
    Read(name, object, arguments, retval, exception);
  else if (name == "absolute")
    Absolute(name, object, arguments, retval, exception);
  else if (name == "list")
    List(name, object, arguments, retval, exception);
  else if (name == "isFile")
    IsFile(name, object, arguments, retval, exception);
  else if (name == "isDirectory")
    IsDirectory(name, object, arguments, retval, exception);
  else if (name == "openDialog")
    OpenDialog(name, object, arguments, retval, exception);
  else if (name == "open")
    Open(name, object, arguments, retval, exception);
  else if (name == "write")
    Write(name, object, arguments, retval, exception);
  else if (name == "writeToPasteboard")
    WriteToPasteboard(name, object, arguments, retval, exception);
  else if (name == "readFromPasteboard")
    ReadFromPasteboard(name, object, arguments, retval, exception);
  else if (name == "asyncList")
    AsyncList(name, object, arguments, retval, exception);
  else if (name == "makeDirectory")
    MakeDirectory(name, object, arguments, retval, exception);
  else if (name == "move")
    Move(name, object, arguments, retval, exception);
  else if (name == "remove")
    Remove(name, object, arguments, retval, exception);
  else if (name == "alert")
    Alert(name, object, arguments, retval, exception);
  else if (name == "watchPath")
    WatchPath(name, object, arguments, retval, exception);
  else if (name == "unwatchPath")
    UnwatchPath(name, object, arguments, retval, exception);
  else if (name == "md5ForPath")
    Digest(name, object, arguments, retval, exception);
  else if (name == "lastModified")
    LastModified(name, object, arguments, retval, exception);
  else
    cout << "Unhandled -> " + name.ToString() << " : "
        << arguments[0]->GetStringValue().ToString() << endl;
  return true;
}

}
