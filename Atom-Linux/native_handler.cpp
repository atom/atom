#include "native_handler.h"
#include "include/cef_base.h"
#include "client_handler.h"
#include <iostream>
#include <fstream>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <vector>
#include <gtk/gtk.h>

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

void ListDirectory(string path, vector<string>* paths, bool recursive) {
	dirent **children;
	int childrenCount = scandir(path.c_str(), &children, 0, alphasort);
	struct stat statResult;
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
			result = stat(entryPath.c_str(), &statResult);
			if (result == 0 && S_ISDIR(statResult.st_mode))
				ListDirectory(entryPath, paths, recursive);
		}
		free(children[i]);
	}
	free(children);
}

void NativeHandler::List(const CefString& name, CefRefPtr<CefV8Value> object,
		const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval,
		CefString& exception) {
	string path = arguments[0]->GetStringValue().ToString();
	bool recursive = arguments[1]->GetBoolValue();
	vector < string > *paths = new vector<string>;
	ListDirectory(path, paths, recursive);

	retval = CefV8Value::CreateArray();
	for (uint i = 0; i < paths->size(); i++)
		retval->SetValue(i, CefV8Value::CreateString(paths->at(i)));
	free (paths);
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

	ofstream myfile;
	myfile.open(path.c_str());
	myfile << content;
	myfile.close();
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

	CefRefPtr<CefV8Value> callbackPaths = CefV8Value::CreateArray();
	for (uint i = 0; i < paths->size(); i++)
		callbackPaths->SetValue(i, CefV8Value::CreateString(paths->at(i)));
	CefV8ValueList args;
	args.push_back(callbackPaths);
	CefRefPtr<CefV8Exception> e;
	arguments[2]->ExecuteFunction(arguments[2], args, retval, e, true);
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
	else
		cout << "Unhandled -> " + name.ToString() << " : "
				<< arguments[0]->GetStringValue().ToString() << endl;
	return true;
}
