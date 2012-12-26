.PHONY: install
DATADIR=$(DESTDIR)/usr/share/tkhostman/
BINDIR=$(DESTDIR)/usr/bin/
COMPLETIONDIR=$(DESTDIR)/etc/bash_completion.d/
SOURCES=common/common.tcl common/main.tcl common/plugin_ftp.tcl common/plugin_ssh.tcl
EXECUTABLES=tkhostman sshto sshpass

all:

install:
	mkdir -p $(DATADIR) $(BINDIR) $(COMPLETIONDIR)
	cp $(SOURCES) $(DATADIR)
	cp bash_completion.d/tkhostman.sh $(COMPLETIONDIR)
	cp $(EXECUTABLES) $(BINDIR)
