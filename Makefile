# /.../
# Copyright (c) 2006 SUSE LINUX Products GmbH. All rights reserved.
# Author: Marcus Schaefer <ms@suse.de>, 2006
#
# Makefile for SUSE - Product Builder
# ---
buildroot = /

XML_CATALOG_FILES = .catalog.xml

export

#============================================
# Prefixs...
#--------------------------------------------
kiwi_prefix = ${buildroot}/usr/share/kiwi

#============================================
# Variables... 
#--------------------------------------------
KIWIMODVZ   = ${kiwi_prefix}/modules
KIWIXSLVZ   = ${kiwi_prefix}/xsl

all: modules/KIWISchema.rng
	@echo Compiling...
	#============================================
	# build tools
	#--------------------------------------------
	${MAKE} -C tools all
	${MAKE} -C locale all

	#============================================
	# install .revision file
	#--------------------------------------------
	test -f ./.revision || ./.version > .revision

install: uninstall
	@echo Installing...
	#============================================
	# Install base directories
	#--------------------------------------------
	install -d -m 755 ${KIWIMODVZ} ${KIWIXSLVZ}

	#============================================
	# install .revision file
	#--------------------------------------------
	install -m 644 ./.revision ${kiwi_prefix}

	#============================================
	# Install KIWI base and modules
	#--------------------------------------------
	install -m 755 ./kiwi.pl       ${KIWIBINVZ}/kiwi
	install -m 644 ./xsl/*         ${KIWIXSLVZ}
	for i in $(shell find modules -type f | grep -v -E '\.test');do \
		install -m 644 $$i ${KIWIMODVZ} ;\
	done

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
