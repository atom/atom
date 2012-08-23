INSTALLDIR=/usr/share/atom

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
	-I/usr/include/openssl \
	-I/usr/lib/glib-2.0/include \
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
	-Wl,-rpath=$(INSTALLDIR)

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
	-lgobject-2.0 \
	-lgmodule-2.0 \
	-lgthread-2.0 \
	-lrt \
	-lglib-2.0 \
	-lssl \
	-lcrypto \
	-lcef \
	-lcef_dll_wrapper \
	-lonig

SOURCES=atom.cpp native_handler.cpp client_handler.cpp onig_regexp_extension.cpp io_utils.cpp
OBJECTS=$(SOURCES:.cpp=.o)

all:
	g++ $(CXXFLAGS) -c $(SOURCES)
	g++ -o atom $(OBJECTS) $(LDFLAGS) $(LIBS)

clean:
	rm -rf atom *.o

install:
	mkdir -p $(INSTALLDIR)
	cp atom $(INSTALLDIR)
	cp chrome.pak $(INSTALLDIR)
	cp -R locales $(INSTALLDIR)
	cp atom.png $(INSTALLDIR)
	cp lib/libcef.so $(INSTALLDIR)
	cp lib/libcef_dll_wrapper.a $(INSTALLDIR)
	cp -R ../src $(INSTALLDIR)
	cp -R ../static $(INSTALLDIR)
	cp -R ../vendor $(INSTALLDIR)
	cp -R ../bundles $(INSTALLDIR)
	cp -R ../themes $(INSTALLDIR)
	cp ../index.html $(INSTALLDIR)
	coffee -c -o $(INSTALLDIR)/src/stdlib ../src/stdlib/require.coffee
	ln -sf $(INSTALLDIR)/atom /usr/local/bin/atom

spec-install: install
	cp -R ../spec $(INSTALLDIR)
