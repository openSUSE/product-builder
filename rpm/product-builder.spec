#
# spec file for package product-builder
#
# Copyright (c) 2017 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.
#
# Please submit bugfixes or comments via:
#
#       https://github.com/openSUSE/product-builder/issues
#
#
Summary:        SUSE Product Builder
Url:            http://github.com/openSUSE/product-builder
Name:           product-builder
License:        GPL-2.0
Group:          System/Management
Version:        1.01.01
Provides:       kiwi-schema = 6.2
Release:        0
Source:         %name-%version.tar.xz

Requires:       perl >= %{perl_version}
Requires:       libxslt
Requires:       perl-Class-Singleton
Requires:       perl-Config-IniFiles >= 2.49
Requires:       perl-File-Slurp
Requires:       perl-JSON
Requires:       perl-Readonly
Requires:       perl-XML-LibXML
Requires:       perl-XML-LibXML-Common
Requires:       perl-XML-SAX
Requires:       perl-libwww-perl

Provides:       kiwi-packagemanager:instsource
Requires:       build
Requires:       inst-source-utils
Requires:       product-builder-plugin
Requires:       genisoimage
%ifarch %ix86 x86_64
Requires:       syslinux
%endif

%description
The SUSE product builder, builds product media (CD/DVD) for
the SUSE product portfolio. Based on kiwi perl implementation.

To be used only for product medias after openSUSE 13.2, Leap 42 
and SLE 12.

%prep
%setup -q

%build
test -e /.buildenv && . /.buildenv
make buildroot=$RPM_BUILD_ROOT CFLAGS="$RPM_OPT_FLAGS"

%install
make buildroot=$RPM_BUILD_ROOT \
    doc_prefix=$RPM_BUILD_ROOT/%{_defaultdocdir} \
    man_prefix=$RPM_BUILD_ROOT/%{_mandir} \
    install

%files
%defattr(-, root, root)
%dir %{_datadir}/kiwi
%{_datadir}/kiwi/modules
%{_datadir}/kiwi/xsl
%{_sbindir}/kiwi

%changelog
