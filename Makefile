# Clover: `make` builds, `make test` tests, `make app` bundles dist/Clover.app,
# `make install` moves it to /Applications and links ~/.local/bin/cl.

APP     := dist/Clover.app
BIN     := .build/release
# Swift Testing ships outside the default search paths with the Command Line Tools.
DEV     := $(shell xcode-select -p)/Library/Developer
TESTING := -Xswiftc -F -Xswiftc $(DEV)/Frameworks \
           -Xlinker -rpath -Xlinker $(DEV)/Frameworks -Xlinker -rpath -Xlinker $(DEV)/usr/lib

.PHONY: build test app install clean

build:
	swift build

test:
	swift test $(TESTING)

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BIN)/Clover $(BIN)/cl $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	cp Resources/Clover.icns $(APP)/Contents/Resources/
	codesign --force --sign - --timestamp=none $(APP)/Contents/MacOS/cl
	codesign --force --sign - --timestamp=none $(APP)

install: app
	rm -rf /Applications/Clover.app
	mv $(APP) /Applications/
	mkdir -p ~/.local/bin
	ln -sf /Applications/Clover.app/Contents/MacOS/cl ~/.local/bin/cl

clean:
	rm -rf .build dist
