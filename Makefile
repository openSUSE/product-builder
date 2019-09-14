# /.../
# Copyright (c) 2006 SUSE LINUX Products GmbH. All rights reserved.
# Author: Marcus Schaefer <ms@suse.de>, 2006
#
# Makefile for SUSE - Product Builder
# ---

XML_CATALOG_FILES = .catalog.xml

export

#============================================
# Prefixs...
#--------------------------------------------
kiwi_prefix = ${buildroot}/usr/share/kiwi
KIWIBINVZ   = ${buildroot}/usr/bin

#============================================
# Variables... 
#--------------------------------------------
KIWIMETAVZ  = ${kiwi_prefix}/metadata
KIWIMODVZ   = ${kiwi_prefix}/modules
KIWIXSLVZ   = ${kiwi_prefix}/xsl

all: modules/KIWISchema.rng

install: uninstall
	@echo Installing...
	#============================================
	# Install base directories
	#--------------------------------------------
	install -d -m 755 ${KIWIMODVZ} ${KIWIXSLVZ} ${KIWIBINVZ} ${KIWIMETAVZ}

	#============================================
	# Install KIWI base and modules
	#--------------------------------------------
	install -m 755 ./product-builder.pl ${KIWIBINVZ}/product-builder.pl
	install -m 755 ./SLE-wrapper.sh     ${KIWIBINVZ}/product-builder-sle.sh
	install -m 644 ./xsl/*              ${KIWIXSLVZ}
	for i in $(shell find modules -type f | grep -v -E '\.test');do \
		install -m 644 $$i ${KIWIMODVZ} ;\
	done

	#============================================
	# Install KIWI metadata files
	#--------------------------------------------
	install -m 644 metadata/* ${KIWIMETAVZ}

modules/KIWISchema.rng: modules/KIWISchema.rnc
	@echo Building Schema...
	#============================================
	# Convert RNC -> RNG...
	#--------------------------------------------
	@echo "*** Converting KIWI RNC -> RNG..."
	trang -I rnc -O rng modules/KIWISchema.rnc modules/KIWISchema.rng

clean:
	@echo Cleanup...
	rm -f .revision
	rm -f .kiwirc

uninstall:
	@echo Uninstalling...
	rm -rf ${buildroot}/usr/share/kiwi

build: clean
	./.doit -p --local
