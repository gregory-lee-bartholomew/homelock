# vim:set ts=3:

installfiles := homelock homelock.conf

selinuxdevel := /usr/share/selinux/devel
sepolicypkgs := homelock.pp

se_fcontexts := -t mount_exec_t "/etc/security/homelock"

all :
	echo "usage: make <install|sepolicy_install|uninstall>"

test :
	test -w /etc/security || \
		(echo "access denied, (missing sudo?)" 1>&2; exit 1)

install : test
	for i in $(installfiles); do \
		echo "installing $$i..."; \
		cp $$i /etc/security; \
	done
	chmod -v +x /etc/security/homelock
	./pam-config add
	./tty-config add

%.pp : %.te
	test -e $(selinuxdevel) || \
		(echo "error, selinux-policy-devel is not installed." 1>&2; exit 1)
	tmpdir=`mktemp -d`; \
		trap 'rm -rf "$$tmpdir"' exit; \
		cp $< $$tmpdir; \
		$(MAKE) -C $$tmpdir -f $(selinuxdevel)/Makefile $@ &> /dev/null; \
		cp $$tmpdir/$@ .

sepolicy : $(sepolicypkgs)

sepolicy_install : sepolicy
	semodule -v -i $(sepolicypkgs)
	semanage fcontext -a $(se_fcontexts)
	restorecon -v "/etc/security/homelock"

uninstall : test
	semanage fcontext -d $(se_fcontexts) || :
	semodule -l | grep -w -e homelock | \
		xargs -r -n 1 semodule -v -r || :
	./tty-config remove || :
	./pam-config remove
	for i in $(installfiles); do rm -vf /etc/security/$$i; done

.PHONY : all test install sepolicy sepolicy_install uninstall

.SILENT :

