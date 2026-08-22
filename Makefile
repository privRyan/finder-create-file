.PHONY: build package test verify-package install uninstall clean

build:
	./scripts/build.sh

package:
	./scripts/package.sh

verify-package:
	./tests/verify-package.sh

test: build
	./tests/verify.sh

install: build
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh

clean:
	rm -rf .build dist
