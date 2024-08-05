# vim:set ts=3:

pool ?= root

selinuxdevel := /usr/share/selinux/devel/Makefile
se_fcontexts := -t mount_exec_t "/etc/security/homelock"

all :
	echo "usage: make <install|sepolicy_install|uninstall|sepolicy_uninstall>"

test :
	test -w /etc/security || \
		(echo "access denied, (missing sudo?)" 1>&2; exit 1)

install : test
	cp -v homelock /etc/security
	cp -n -v homelock.conf /etc/security || :
	sed -i "/^POOL=/ s/=.*/='${pool}'/;" /etc/security/homelock.conf
	chmod -v +x /etc/security/homelock
	./pam-config add
	./tty-config add
	printf 'kernel.printk = %s\n' "$$(sed 's/[0-7]/0/' /proc/sys/kernel/printk)" \
		> /etc/sysctl.d/homelock.conf

%.pp : %.te
	test -e $(selinuxdevel) || \
		(echo "error, selinux-policy-devel is not installed." 1>&2; exit 1)
	tmpdir=`mktemp -d`; \
		cp $< $$tmpdir; \
		$(MAKE) -C $$tmpdir -f $(selinuxdevel) $@ &> /dev/null; \
		ln -sf $$tmpdir/$@ .

sepolicy : homelock.pp

sepolicy_install : sepolicy
	semanage fcontext -a $(se_fcontexts)
	restorecon -v "/etc/security/homelock"
	semodule -v -i homelock.pp
	rm -rf "$(readlink -f homelock.pp | xargs -r dirname)"
	rm -f homelock.pp

uninstall : test
	./tty-config remove || :
	./pam-config remove
	rm -vf /etc/security/homelock{,.conf}
	rm -vf /etc/sysctl.d/homelock.conf

sepolicy_uninstall :
	semanage fcontext -d $(se_fcontexts) || :
	semodule -l | grep -w -e homelock | \
		xargs -r -n 1 semodule -v -r

.PHONY : all test install sepolicy sepolicy_install uninstall sepolicy_uninstall

.SILENT :

