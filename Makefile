# ionix-quickshell
#
# The QML tree installs to /etc/xdg/quickshell/ionix, which is where Quickshell
# looks for system-provided configs (XDG_CONFIG_DIRS). Users override with
# ~/.config/quickshell/ionix/config.json without shadowing this tree, because
# Quickshell only treats a directory as a config if it contains shell.qml.

PREFIX  ?= /usr
DESTDIR ?=
PKGNAME ?= ionix-quickshell

SHELLDIR = $(DESTDIR)/etc/xdg/quickshell/ionix
BINDIR   = $(DESTDIR)$(PREFIX)/bin
UNITDIR  = $(DESTDIR)$(PREFIX)/lib/systemd/user
LICDIR   = $(DESTDIR)$(PREFIX)/share/licenses/$(PKGNAME)

.PHONY: install uninstall lint dev check

install:
	@# install -D each file individually rather than cp -r, so modes are
	@# normalised to 0644 instead of inheriting whatever the checkout had.
	@find ionix -type f | while read -r f; do \
		install -Dm644 "$$f" "$(SHELLDIR)/$${f#ionix/}"; \
	done
	install -Dm755 bin/ionix-shell-qs   $(BINDIR)/ionix-shell-qs
	install -Dm755 bin/ionix-shell-fork $(BINDIR)/ionix-shell-fork
	install -Dm644 systemd/ionix-quickshell.service $(UNITDIR)/ionix-quickshell.service
	install -Dm644 LICENSE $(LICDIR)/LICENSE

uninstall:
	rm -rf $(SHELLDIR)
	rm -f $(BINDIR)/ionix-shell-qs $(BINDIR)/ionix-shell-fork
	rm -f $(UNITDIR)/ionix-quickshell.service
	rm -rf $(LICDIR)

lint:
	qmlformat -i $$(find ionix -name '*.qml')

# Symlink a checkout into the user config path so `qs -c ionix` picks it up and
# hot-reloads on save. Removes an existing symlink, refuses to clobber a real dir.
dev:
	@target="$$HOME/.config/quickshell/ionix"; \
	mkdir -p "$$HOME/.config/quickshell"; \
	if [ -L "$$target" ]; then rm "$$target"; \
	elif [ -e "$$target" ]; then echo "refusing to replace real directory $$target"; exit 1; fi; \
	ln -s "$(CURDIR)/ionix" "$$target"; \
	echo "linked $$target -> $(CURDIR)/ionix"; \
	echo "run: qs -c ionix"

check:
	@ok=1; for f in $$(find ionix -name '*.qml'); do \
		qmlformat "$$f" >/dev/null || { echo "PARSE FAIL: $$f"; ok=0; }; \
	done; [ $$ok = 1 ] && echo "all QML files parse"
