CXXFLAGS := -Werror \
	-pthread \
	-fno-exceptions \
	-fno-strict-aliasing \
	-Wall \
	-Wno-unused-parameter \
	-Wno-missing-field-initializers \
	-fvisibility=hidden \
	-pipe \
	-fPIC \
	-pthread \
	-D_REENTRANT \
	-I/usr/include/gtk-2.0 \
	-I/usr/lib/gtk-2.0/include \
	-I/usr/include/atk-1.0 \
	-I/usr/include/cairo \
	-I/usr/include/pango-1.0 \
	-I/usr/include/gio-unix-2.0/ \
	-I/usr/include/glib-2.0 \
	-I/usr/lib/glib-2.0/include \
	-I/usr/include/pixman-1 \
	-I/usr/include/freetype2 \
	-I/usr/include/directfb \
	-I/usr/include/libpng12 \
	-I../cef \
	-O2 \
	-fno-ident \
	-fdata-sections \
	-ffunction-sections \
	-fno-rtti \
	-fno-threadsafe-statics \
	-fvisibility-inlines-hidden \
	-Wsign-compare

LDFLAGS := -pthread \
	-Wl,-z,noexecstack \
	-fPIC \
	-Llib \
	-Wl,-O1 \
	-Wl,--as-needed \
	-Wl,--gc-sections \

LIBS := -lX11 \
	-lgtk-x11-2.0 \
	-lgdk-x11-2.0 \
	-latk-1.0 \
	-lgio-2.0 \
	-lpangoft2-1.0 \
	-lgdk_pixbuf-2.0 \
	-lm \
	-lpangocairo-1.0 \
	-lcairo \
	-lpango-1.0 \
	-lfreetype \
	-lfontconfig \
	-lgobject-2.0 \
	-lgmodule-2.0 \
	-lgthread-2.0 \
	-lrt \
	-lglib-2.0 \
	-lcef \
	-lcef_dll_wrapper

SOURCES=atom.cpp cefclient.cpp native_handler.cpp cefclient_switches.cpp client_handler.cpp client_handler_gtk.cpp
OBJECTS=$(SOURCES:.cpp=.o)

all:
	g++ $(CXXFLAGS) -c $(SOURCES)
	mkdir -p out
	cp chrome.pak out/
	cp -R locales out/
	cp atom.png out/
	g++ -o out/atom $(OBJECTS) $(LDFLAGS) $(LIBS)
	
clean:
	rm -rf out *.o
