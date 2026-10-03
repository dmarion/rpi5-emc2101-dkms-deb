# Microchip EMC2101 hwmon driver: out-of-tree build and DKMS .deb packaging.
#
#   make            build emc2101-dkms_<version>_all.deb
#   make modules    build emc2101.ko against the running (or KVER) kernel
#   make clean      remove build artifacts

PACKAGE    := emc2101
VERSION    := 0.3
DEBREV     := 3
DEBVERSION := $(VERSION)-$(DEBREV)
DEB        := $(PACKAGE)-dkms_$(DEBVERSION)_all.deb

KVER       ?= $(shell uname -r)
KDIR       ?= /lib/modules/$(KVER)/build

MOD_SRC    := emc2101.c Kbuild
DOCS       := emc2101.rst microchip,emc2101.yaml
OVERLAYS   := i2c1-sda-hold emc2101-i2c1
DTBOS      := $(OVERLAYS:%=build/%.dtbo)
SCRIPTS    := postinst prerm postrm
DEB_SRC    := $(MOD_SRC) dkms.conf $(DOCS) $(DTBOS) \
              extras/emc2101-setup extras/90-emc2101.rules extras/emc2101.default \
              debian/control debian/copyright $(SCRIPTS:%=debian/%)

STAGE      := build/deb
SRCDIR     := $(STAGE)/usr/src/$(PACKAGE)-$(VERSION)
DOCDIR     := $(STAGE)/usr/share/doc/$(PACKAGE)-dkms

.PHONY: all deb modules clean

all: deb

deb: $(DEB)

build/%.dtbo: extras/%.dts
	@mkdir -p build
	dtc -@ -q -I dts -O dtb -o $@ $<

$(DEB): $(DEB_SRC) Makefile
	rm -rf $(STAGE)
	install -d $(SRCDIR) $(DOCDIR) $(STAGE)/DEBIAN
	install -m 644 $(MOD_SRC) $(SRCDIR)/
	sed 's/@VERSION@/$(VERSION)/' dkms.conf > $(SRCDIR)/dkms.conf
	install -m 644 $(DOCS) debian/copyright $(DOCDIR)/
	install -D -m 644 -t $(STAGE)/usr/lib/emc2101/overlays $(DTBOS)
	install -D -m 755 extras/emc2101-setup $(STAGE)/usr/sbin/emc2101-setup
	install -D -m 644 extras/90-emc2101.rules $(STAGE)/usr/lib/udev/rules.d/90-emc2101.rules
	install -D -m 644 extras/emc2101.default $(STAGE)/etc/default/emc2101
	echo /etc/default/emc2101 > $(STAGE)/DEBIAN/conffiles
	sed 's/@DEBVERSION@/$(DEBVERSION)/' debian/control > $(STAGE)/DEBIAN/control
	for s in $(SCRIPTS); do \
		sed 's/@VERSION@/$(VERSION)/' debian/$$s > $(STAGE)/DEBIAN/$$s; \
		chmod 755 $(STAGE)/DEBIAN/$$s; \
	done
	chmod -R u=rwX,go=rX $(STAGE)
	dpkg-deb --root-owner-group --build $(STAGE) $@

modules:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	rm -rf build $(DEB)
	if [ -d $(KDIR) ]; then $(MAKE) -C $(KDIR) M=$(CURDIR) clean; fi
