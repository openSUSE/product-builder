#
# spec file for package product-builder
#
# Copyright (c) 2018 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Summary:        SUSE Product Builder
License:        GPL-2.0-only
Group:          System/Management
Url:            http://github.com/openSUSE/product-builder
Name:           product-builder
Conflicts:      kiwi
Conflicts:      kiwi-instsource
Version:        1.0.5
Release:        0
Provides:       kiwi-schema = 6.2
Source:         product-builder-%version.tar.xz
# temporary hack for openSUSE:Factory only
Patch1:         accept_old_meta_package.patch

Requires:       libxslt
Requires:       perl >= %{perl_version}
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
Provides:       system-packages:kiwi-product
Requires:       build
Requires:       checkmedia
Requires:       mkisofs
Requires:       inst-source-utils
Requires:       product-builder-plugin
%ifarch %ix86 x86_64
Requires:       syslinux
%endif

%description
The SUSE product builder, builds product media (CD/DVD) for
the SUSE product portfolio. Based on kiwi perl implementation.

To be used only for product medias for Leap 15 and SLE 15.

%prep
%setup -q
%if 0%{?suse_version} == 1330 || 0%{?skelcd_compat}
%patch1 -p1
%endif

%build
test -e /.buildenv && . /.buildenv
make buildroot="%{buildroot}" CFLAGS="%{optflags}"

%install
make buildroot="%{buildroot}" \
    doc_prefix="%{buildroot}/%{_defaultdocdir}" \
    man_prefix="%{buildroot}/%{_mandir}" \
    install
./.version >"%{buildroot}/%{_datadir}/kiwi/.revision"

%files
%defattr(-, root, root)
%dir %{_datadir}/kiwi
%doc LICENSE
%{_datadir}/kiwi/.revision
%{_datadir}/kiwi/metadata
%{_datadir}/kiwi/modules
%{_datadir}/kiwi/xsl
%{_bindir}/product-builder

%changelog
