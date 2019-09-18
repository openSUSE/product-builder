#!/bin/bash

# wrapper around product builder to call itself recursive for SLE Packages DVD

set -xe

case "$BUILD_FLAVOR" in
  SLES-cd-Packages-DVD-*)
    TOPDIR=/usr/src/packages/
    cd $TOPDIR/SOURCES/ || exit 1
    mkdir $TOPDIR/KIWIRESULTS

    # remove symlink, we cat into it
    rm config.xml

    ARCH=${BUILD_FLAVOR/SLES-cd-Packages-DVD-}
    # the worker expands obsrepositories:// only in the target kiwi so we need to apply this change to the modules
    perl -e '$in=0; while (<STDIN>) { $in=1 if /<instrepo /; print $_ if $in; $in=0 if m,</instrepo,; }' < $BUILD_FLAVOR.kiwi > expanded_instsources.include

    # map the build number to the modules
    BUILD_SUFFIX=`sed -ne "s/.*name=\"MEDIUM_NAME\">.*-$ARCH-\([^<]*\)-Media<.*/\1/p" $BUILD_FLAVOR.kiwi`

    rm -rf $TOPDIR/KIWIALL
    mkdir $TOPDIR/KIWIALL

    for kiwi in *-$ARCH.kiwi; do
      MN=`sed -ne "s/.*name=\"MEDIUM_NAME\">\([^<]*\)<.*/\1/p" $kiwi`

      MN_SHORT=${MN%-POOL-*}
      grep -qx $MN_SHORT packages-dvd.txt || continue

      # replace obsrepositories://
      perl -e '$in=0; while (<STDIN>) { $in=1 if /<instrepo /; print $_ unless $in; if (m,</instrepo,) { $in=0; system("cat expanded_instsources.include") }; }' < $kiwi > config.xml
      sed -i "s,MEDIUM_NAME\">.*,MEDIUM_NAME\">$MN-$BUILD_SUFFIX-Media</productvar><productvar name=\"BUILD_ID\">$MN-$BUILD_SUFFIX</productvar>," config.xml

      /usr/bin/product-builder.pl --root $TOPDIR/KIWIROOT/ -v 1 --logfile terminal --create-instsource . || exit 1
      mv $TOPDIR/KIWIROOT/main $TOPDIR/KIWIALL/$MN_SHORT
      rm -rf $TOPDIR/KIWIROOT
    done # kiwiconf

    # now the final ISO
    perl -e '$in=0; while (<STDIN>) { $in=0 if m,</repopackages,; print $_ unless $in; $in=1 if m,<repopackages,; }' < $BUILD_FLAVOR.kiwi  > config.xml
    ;;
esac

exec /usr/bin/product-builder.pl $@
