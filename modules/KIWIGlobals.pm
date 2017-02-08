#================
# FILE          : KIWIGlobals.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : SUSE Product Builder
#               :
# DESCRIPTION   : This module is used to store variables and
#               : functions which needs to be available globally
#               :
# STATUS        : Stable
#----------------
package KIWIGlobals;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use File::Basename;
use Config::IniFiles;
use LWP;

#==========================================
# Base class
#------------------------------------------
use base qw /Class::Singleton/;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWILocator;
use KIWILog;
use KIWIQX;

#==========================================
# One time initialization code
#------------------------------------------
sub _new_instance {
    # ...
    # Construct a KIWIGlobals object. The globals object holds configuration
    # data for kiwi itself and provides methods
    # ---
    #==========================================
    # Object setup
    #------------------------------------------
    my $this  = {};
    my $class = shift;
    bless $this,$class;
    #==========================================
    # Constructor setup
    #------------------------------------------
    my $arch = qx(uname -m);
    chomp $arch;
    #==========================================
    # Globals (generic)
    #------------------------------------------
    my %data;
    $data{Version}         = "1.01.01";
    $data{Publisher}       = "SUSE LINUX GmbH";
    $data{Preparer}        = "KIWI - http://opensuse.github.com/kiwi";
    $data{ConfigName}      = "config.xml";
    $data{PackageManager}  = "zypper";
    #============================================
    # Read .kiwirc
    #--------------------------------------------
    my $file;
    if (-f '.kiwirc') {
        $file = '.kiwirc';
    }
    elsif (($ENV{'HOME'}) && (-f $ENV{'HOME'}.'/.kiwirc')) {
        $file = "$ENV{'HOME'}/.kiwirc";
    }
    my $kiwi = KIWILog -> instance();
    $this->{kiwi} = $kiwi;
    if ($file) {
        if (! do $file) {
            $kiwi -> warning ("Invalid $file file...");
            $kiwi -> skipped ();
        } else {
            $kiwi -> info ("Using $file");
            $kiwi -> done ();
        }
    }
    ## no critic
    no strict 'vars';
    $data{BasePath}      = $BasePath;      # configurable base kiwi path
    $data{Gzip}          = $Gzip;          # configurable gzip command
    $data{Xz}            = $Xz;            # configurable xz command
    $data{System}        = $System;        # configurable base image desc. path
    if ( ! defined $BasePath ) {
        $data{BasePath} = "/usr/share/kiwi";
    }
    if (! defined $Gzip) {
        $data{Gzip} = "gzip -9";
    }
    if (! defined $Xz) {
        $data{Xz} = "xz -6";
    }
    if (! defined $System) {
        $data{System} = $data{BasePath}."/image";
    }
    use strict 'vars';
    ## use critic
    my $BasePath = $data{BasePath};
    #==========================================
    # Globals (path names)
    #------------------------------------------
    $data{Tools}       = $BasePath."/tools";
    $data{Schema}      = $BasePath."/modules/KIWISchema.rng";
    $data{KConfig}     = $BasePath."/modules/KIWIConfig.sh";
    $data{KModules}    = $BasePath."/modules";
    $data{Revision}    = $BasePath."/.revision";
    $data{SchemaCVT}   = $BasePath."/xsl/master.xsl";
    $data{Pretty}      = $BasePath."/xsl/print.xsl";
    #==========================================
    # Store object data
    #------------------------------------------
    $this->{data} = \%data;
    return $this;
}

#==========================================
# getArch
#------------------------------------------
sub getArch {
    # ...
    # Return the architecture setting of the build environment
    # ---
    my $arch = KIWIQX::qxx ("uname -m"); chomp $arch;
    return $arch;
}

#==========================================
# getKiwiConfig
#------------------------------------------
sub getKiwiConfig {
    # ...
    # Return a hash of all the KIWI configuration data
    # ---
    my $this = shift;
    return $this->{data};
}

#==========================================
# downloadFile
#------------------------------------------
sub downloadFile {
    # ...
    # download a file from a network or local location to
    # a given local path. It's possible to use regular expressions
    # in the source file specification
    # ---
    my $this    = shift;
    my $url     = shift;
    my $dest    = shift;
    my $kiwi    = $this->{kiwi};
    my $dirname;
    my $basename;
    my $proxy;
    my $user;
    my $pass;
    #==========================================
    # Check parameters
    #------------------------------------------
    if ((! defined $dest) || (! defined $url)) {
        return;
    }
    #==========================================
    # setup destination base and dir name
    #------------------------------------------
    if ($dest =~ /(^.*\/)(.*)/) {
        $dirname  = $1;
        $basename = $2;
        if (! $basename) {
            $url =~ /(^.*\/)(.*)/;
            $basename = $2;
        }
    } else {
        return;
    }
    #==========================================
    # check base and dir name
    #------------------------------------------
    if (! $basename) {
        return;
    }
    if (! -d $dirname) {
        return;
    }
    #==========================================
    # quote shell escape sequences
    #------------------------------------------
    $url =~ s/(["\$`\\])/\\$1/g;
    #==========================================
    # download file
    #------------------------------------------
    if ($url !~ /:\/\//) {
        # /.../
        # local files, make them a file:// url
        # ----
        $url = "file://".$url;
        $url =~ s{/{3,}}{//};
    }
    if ($url =~ /dir:\/\//) {
        # /.../
        # dir url, make them a file:// url
        # ----
        $url =~ s/^dir/file/;
    }
    if ($url =~ /^(.*)\?(.*)$/) {
        $url=$1;
        my $redirect=$2;
        if ($redirect =~ /(.*?)\/(.*)?$/) {
            $redirect = $1;
            $url.='/'.$2;
        }
        # get proxy url:
        # \bproxy makes sure it does not pick up "otherproxy=unrelated"
        # (?=&|$) makes sure the captured substring is followed by an
        # ampersand or the end-of-string
        # ----
        if ($redirect =~ /\bproxy=(.*?)(?=&|$)/) {
            $proxy = "$1";
        }
        # remove locator string e.g http://
        if ($proxy) {
            $proxy =~ s/^.*\/\///;
        }
        # extract credentials user and password
        if ($redirect =~ /proxyuser=(.*)\&proxypass=(.*)/) {
            $user=$1;
            $pass=$2;
        }
    }
    #==========================================
    # Create lwp-download callback
    #------------------------------------------
    my $lwp = KIWIQX::qxx ("mktemp -qt kiwi-lwp-download-XXXXXX 2>&1");
    my $code = $? >> 8; chomp $lwp;
    if ($code != 0) {
        $kiwi->loginfo("Couldn't create tmp file: $lwp: $!");
        return;
    }
    my $LWP = FileHandle -> new();
    if (! $LWP -> open (">$lwp")) {
        $kiwi->loginfo("downloadFile::Failed to create $lwp: $!");
        return;
    }
    if ($proxy) {
        print $LWP 'export PERL_LWP_ENV_PROXY=1'."\n";
        if (($user) && ($pass)) {
            print $LWP "export http_proxy=http://$user:$pass\@$proxy\n";
        } else {
            print $LWP "export http_proxy=http://$proxy\n";
        }
    }
    my $locator = KIWILocator -> instance();
    my $lwpload = $locator -> getExecPath ('lwp-download');
    if (! $lwpload) {
        $kiwi->loginfo("downloadFile::Can't find lwp-download");
        $LWP -> close();
        unlink $lwp;
        return;
    }
    print $LWP $lwpload.' "$1" "$2"'."\n";
    $LWP -> close();
    # /.../
    # use lwp-download to manage the process.
    # if first download failed check the directory list with
    # a regular expression to find the file. After that repeat
    # the download
    # ----
    KIWIQX::qxx ("chmod a+x $lwp 2>&1");
    KIWIQX::qxx ("chmod a+w $lwp 2>&1");
    $dest = $dirname."/".$basename;
    my $data = KIWIQX::qxx ("$lwp $url $dest 2>&1");
    $code = $? >> 8;
    if ($code == 0) {
        unlink $lwp;
        return $url;
    }
    if ($url =~ /(^.*\/)(.*)/) {
        my $location = $1;
        my $search   = $2;
        my $browser  = LWP::UserAgent -> new;
        my $request  = HTTP::Request  -> new (GET => $location);
        my $response;
        eval {
            $response = $browser  -> request ( $request );
        };
        if ($@) {
            unlink $lwp;
            return;
        }
        my $content  = $response -> content ();
        my @lines    = split (/\n/,$content);
        foreach my $line(@lines) {
            if ($line !~ /href=\"(.*)\"/) {
                next;
            }
            my $link = $1;
            if ($link =~ /$search/) {
                $url  = $location.$link;
                $data = KIWIQX::qxx ("$lwp $url $dest 2>&1");
                $code = $? >> 8;
                if ($code == 0) {
                    unlink $lwp;
                    return $url;
                }
            }
        }
        unlink $lwp;
        return;
    } else {
        unlink $lwp;
        return;
    }
    unlink $lwp;
    return $url;
}


1;
