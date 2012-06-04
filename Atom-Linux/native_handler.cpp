#include "native_handler.h"
#include "include/cef_base.h"
#include "client_handler.h"
#include <iostream>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <vector>

using namespace std;

NativeHandler::NativeHandler() :
		CefV8Handler() {
	object = CefV8Value::CreateObject(NULL, NULL);

	const char *functionNames[] = { "exists", "alert", "read", "write",
			"absolute", "list", "isFile", "isDirectory", "remove", "asyncList",
			"open", "openDialog", "quit", "writeToPasteboard",
			"readFromPasteboard", "showDevTools", "newWindow", "saveDialog",
			"exit", "watchPath", "unwatchPath", "makeDirectory", "move",
			"moveToTrash" };
	int arrayLength = sizeof(functionNames) / sizeof(const char *);
	for (int i = 0; i < arrayLength; i++) {
		const char *functionName = functionNames[i];
		CefRefPtr<CefV8Value> function = CefV8Value::CreateFunction(
				functionName, this);
		object->SetValue(functionName, function, V8_PROPERTY_ATTRIBUTE_NONE);
	}
}

void NativeHandler::Exists(const CefString& name, CefRefPtr<CefV8Value> object,
		const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
		CefString& exception) {
	string path = arguments[0]->GetStringValue().ToString();
	struct stat sbuf;
	int result = stat(path.c_str(), &sbuf);
	retval = CefV8Value::CreateBool(result == 0);
}

void NativeHandler::Read(const CefString& name, CefRefPtr<CefV8Value> object,
		const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
		CefString& exception) {
	string path = arguments[0]->GetStringValue().ToString();
	int fd = open(path.c_str(), O_RDONLY);
	if (fd < 0)
		return;

	char buffer[8192];
	int r;
	string value;
	while ((r = read(fd, buffer, sizeof buffer)) > 0)
		value.append(buffer, 0, r);
	close(fd);
	retval = CefV8Value::CreateString(value);
}

void NativeHandler::Absolute(const CefString& name,
		CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments,
		CefRefPtr<CefV8Value>& retval, CefString& exception) {
	string path = arguments[0]->GetStringValue().ToString();
	if (path[0] == '~') {
		string resolved = getenv("HOME");
		resolved.append(path.substr(1));
		retval = CefV8Value::CreateString(resolved);
	} else
		retval = CefV8Value::CreateString(path);
}

void NativeHandler::List(const CefString& name, CefRefPtr<CefV8Value> object,
		const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
		CefString& exception) {
	string path = arguments[0]->GetStringValue().ToString();
	DIR *dir;
	if ((dir = opendir(path.c_str())) == NULL)
		return;

	vector < string > paths;
	dirent *entry;

	while ((entry = readdir(dir)) != NULL) {
		if (strcmp(entry->d_name, ".") == 0)
			continue;
		if (strcmp(entry->d_name, "..") == 0)
			continue;
		paths.push_back(entry->d_name);
	}

	closedir(dir);

	retval = CefV8Value::CreateArray();
	for (uint i = 0; i < paths.size(); i++)
		retval->SetValue(i, CefV8Value::CreateString(path + "/" + paths[i]));
}

void NativeHandler::IsFile(const CefString& name, CefRefPtr<CefV8Value> object,
		const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
		CefString& exception) {
	string path = arguments[0]->GetStringValue().ToString();
	struct stat sbuf;
	int result = stat(path.c_str(), &sbuf);
	retval = CefV8Value::CreateBool(result == 0 && S_ISREG(sbuf.st_mode));
}

void NativeHandler::IsDirectory(const CefString& name,
		CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments,
		CefRefPtr<CefV8Value>& retval, CefString& exception) {
	string path = arguments[0]->GetStringValue().ToString();
	struct stat sbuf;
	int result = stat(path.c_str(), &sbuf);
	retval = CefV8Value::CreateBool(result == 0 && S_ISDIR(sbuf.st_mode));
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
		cout << filename << endl;
		g_free(filename);
	}
	gtk_widget_destroy(dialog);
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
	else if (name == "showDevTools")
		CefV8Context::GetCurrentContext()->GetBrowser()->ShowDevTools();
	else if (name == "openDialog")
		OpenDialog(name, object, arguments, retval, exception);
	else
		cout << "Unhandled -> " + name.ToString() << " : "
				<< arguments[0]->GetStringValue().ToString() << endl;
	return true;
}
