#!/usr/bin/perl
#================
# FILE          : kiwi.pl
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This is the main script to provide support
#               : for creating operating system images
#               :
#               :
# STATUS        : $LastChangedBy: ms $
#               : $LastChangedRevision: 1 $
#----------------
use lib './modules','/usr/share/kiwi/modules';
use strict;

#============================================
# perl debugger setup
#--------------------------------------------
# $DB::inhibit_exit = 0;

#============================================
# Modules
#--------------------------------------------
use warnings;
use Carp qw (cluck);
use Getopt::Long;
use File::Basename;
use File::Spec;
use File::Find;
use File::Glob ':glob';
use JSON;

#==========================================
# KIWIModules
#------------------------------------------
use KIWICommandLine;
use KIWIGlobals;
use KIWILocator;
use KIWILog;
use KIWIXML;

#============================================
# UTF-8 for output to stdout
#--------------------------------------------
binmode(STDOUT, ":encoding(UTF-8)");

#============================================
# Globals
#--------------------------------------------
my $kiwi    = KIWILog -> instance();

$kiwi -> setColorOff();

my $global  = KIWIGlobals -> instance();
my $locator = KIWILocator -> instance();

#============================================
# Variables (operation mode)
#--------------------------------------------
my $cmdL;       # Command line data container

#==========================================
# IPC; signal setup
#------------------------------------------
local $SIG{"HUP"}  = \&quit;
local $SIG{"TERM"} = \&quit;
local $SIG{"INT"}  = \&quit;

#==========================================
# main
#------------------------------------------
sub main {
    # ...
    # This is the KIWI project to prepare and build operating
    # system images from a given installation source. The system
    # will create a chroot environment representing the needs
    # of a XML control file. Once prepared KIWI can create several
    # OS image types.
    # ---
    #========================================
    # store caller information
    #----------------------------------------
    $kiwi -> loginfo ("kiwi @ARGV\n");
    $kiwi -> loginfo ("kiwi revision: ".revision()."\n");
    #==========================================
    # Initialize and run
    #------------------------------------------
    init();
    return 1;
}

#==========================================
# init
#------------------------------------------
sub init {
    # ...
    # initialize, check privilege and options. KIWI
    # requires you to perform at least one action.
    # An action is either to prepare or create an image
    # ---
    #==========================================
    # Option variables
    #------------------------------------------
    my $Help;
    my $CreateInstSource;      # create installation source from meta packages
    my $Verbosity;             # control the verbosity level
    my $Version;               # version information
    my $LogFile;               # optional file name for logging
    my $RootTree;              # optional root tree destination
    my $ForceNewRoot;          # force creation of new root directory
    my $Prepare;               # control XML file for building chroot extend
    my $Destination;           # destination directory for logical extends
    
    #==========================================
    # create logger and cmdline object
    #------------------------------------------
    $cmdL = KIWICommandLine -> new ();
    if (! $cmdL) {
        kiwiExit (1);
    }
    my $gdata = $global -> getKiwiConfig();
    #==========================================
    # get options and call non-root tasks
    #------------------------------------------
    my $result = GetOptions(
        "create-instsource=s"   => \$CreateInstSource,
        "help|h"                => \$Help,
        "verbose|v=i"           => \$Verbosity,
        "version"               => \$Version,
        "logfile=s"             => \$LogFile,
        "root|r=s"              => \$RootTree,
        "force-new-root"        => \$ForceNewRoot,
        "prepare|p=s"           => \$Prepare,
    );
    #==========================================
    # Check result of options parsing
    #------------------------------------------
    if ( $result != 1 ) {
        usage(1);
    }
    #========================================
    # set logfile if defined at the cmdline
    #----------------------------------------
    if ($LogFile) {
        $cmdL -> setLogFile($LogFile);
        $kiwi -> info ("Setting log file to: $LogFile\n");
        if (! $kiwi -> setLogFile ( $LogFile )) {
            kiwiExit (1);
        }
    }
    #========================================
    # set root target directory if given
    #----------------------------------------
    if (defined $RootTree) {
        $cmdL -> setRootTargetDir($RootTree)
    }
    #========================================
    # turn destdir into absolute path
    #----------------------------------------
    if (defined $Destination) {
        $Destination = File::Spec->rel2abs ($Destination);
        $cmdL -> setImageTargetDir ($Destination);
    }
    if (defined $Prepare) {
        if (($Prepare !~ /^\//) && (! -d $Prepare)) {
            $Prepare = $gdata->{System}."/".$Prepare;
        }
        $Prepare =~ s/\/$//;
    }
    #========================================
    # non root task: create inst source
    #----------------------------------------
    if (defined $CreateInstSource) {
        createInstSource ($CreateInstSource,$Verbosity);
    }
    #==========================================
    # non root task: Help
    #------------------------------------------
    if (defined $Help) {
        usage(0);
    }
    #==========================================
    # non root task: Version
    #------------------------------------------
    if (defined $Version) {
        version(0);
    }
    usage(1);
    return;
}

#==========================================
# usage
#------------------------------------------
sub usage {
    # ...
    # Explain the available options for this
    # image creation system
    # ---
    my $exit = shift;
    my $date = qx ( date -I ); chomp $date;
    print "SUSE product builder ($date)\n";
    print "Copyright (c) 2017 - SUSE LINUX Products GmbH\n";
    print "\n";
    print "Usage:\n";
    print "    kiwi --create-instsource <image-path>\n";
    print "       [ --root <image-root> ]\n";
    print "\n";
    print "Global Options:\n";
    print "    [ --logfile <filename> | terminal ]\n";
    print "      Write to the log file \`<filename>'\n";
    print "\n";
    print "    [ -v | --verbose <1|2|3> ]\n";
    print "      Controls the verbosity level for the instsource module\n";
    print "\n";
    print "    [ --force-new-root ]\n";
    print "      Force creation of new root directory. If the directory\n";
    print "      already exists, it is deleted.\n";
    print "      system image.\n";
    print "\n";
    print "    [ --version]\n";
    print "      Print product builder version\n";
    print "--\n";
    exit ($exit);
}

#==========================================
# exit
#------------------------------------------
sub kiwiExit {
    my $code = shift;
    my $good = "KIWI exited successfully\n";
    my $bad  = "KIWI exited with error(s)\n";
    #==========================================
    # Reformat log file for human readers...
    #------------------------------------------
    $kiwi -> info("Closing session with ecode: $code\n");
    $kiwi -> setLogHumanReadable();
    #==========================================
    # Check for backtrace and clean flag...
    #------------------------------------------
    if ($code != 0) {
        if ($cmdL -> getDebug()) {
            $kiwi -> printBackTrace();
        }
        $kiwi -> error($bad);
        if ($kiwi -> fileLogging()) {
            $kiwi -> setLogFile("terminal");
            $kiwi -> info($bad);
        }
    } else {
        $kiwi -> info($good);
        if ($kiwi -> fileLogging()) {
            $kiwi -> setLogFile("terminal");
            $kiwi -> info($good);
        }
    }
    #==========================================
    # Move process log to final logfile name...
    #------------------------------------------
    $kiwi -> finalizeLog();
    exit $code;
}

#==========================================
# quit
#------------------------------------------
sub quit {
    # ...
    # signal received, exit safely
    # ---
    $kiwi -> reopenRootChannel();
    $kiwi -> note ("\n*** $$: Received signal $_[0] ***\n");
    kiwiExit (1);
    return;
}

#==========================================
# revision
#------------------------------------------
sub revision {
    my $gdata = $global -> getKiwiConfig();
    my $rev  = "unknown";
    if (open my $FD,'<',$gdata->{Revision}) {
        $rev = <$FD>; close $FD;
    }
    chomp $rev;
    return $rev;
}

#==========================================
# version
#------------------------------------------
sub version {
    # ...
    # Version information
    # ---
    my $exit  = shift;
    my $gdata = $global -> getKiwiConfig();
    if (! defined $exit) {
        $exit = 0;
    }
    my $rev = revision();
    $kiwi -> info ("Version:\n");
    $kiwi -> info ("--> vnr: $gdata->{Version}\n");
    $kiwi -> info ("--> git: $rev\n");
    exit ($exit);
}

#==========================================
# createInstSource
#------------------------------------------
sub createInstSource {
    # /.../
    # create instsource requires the module "KIWICollect.pm".
    # If it is not available, the option cannot be used.
    # kiwi then issues a warning and exits.
    # ----
    my $idesc = shift;
    my $vlevel= shift;
    $kiwi -> deactivateBackTrace();
    my $mod = "KIWICollect";
    eval "require $mod"; ## no critic
    if($@) {
        $kiwi->error("Module <$mod> is not available!");
        kiwiExit (3);
    }
    else {
        $kiwi->info("Module KIWICollect loaded successfully...");
        $kiwi->done();
    }
    $kiwi -> info ("Reading image description [InstSource]...\n");
    my $xml = KIWIXML -> new (
        $idesc,undef,undef,$cmdL
    );
    if (! defined $xml) {
        kiwiExit (1);
    }
    my $pkgMgr = $cmdL -> getPackageManager();
    if ($pkgMgr) {
        $xml -> setPackageManager($pkgMgr);
    }
    #==========================================
    # Initialize installation source tree
    #------------------------------------------
    my $root = $locator -> createTmpDirectory (
        undef, $cmdL->getRootTargetDir(), $cmdL
    );
    if (! defined $root) {
        $kiwi -> error ("Couldn't create instsource root");
        $kiwi -> failed ();
        kiwiExit (1);
    }
    #==========================================
    # Create object...
    #------------------------------------------
    my $collect = KIWICollect -> new ( $xml, $root, $vlevel,$cmdL );
    if (! defined( $collect) ) {
        $kiwi -> error( "Unable to create KIWICollect module." );
        $kiwi -> failed ();
        kiwiExit( 1 );
    }
    if (! defined( $collect -> Init () ) ) {
        $kiwi -> error( "Object initialisation failed!" );
        $kiwi -> failed ();
        kiwiExit( 1 );
    }
    #==========================================
    # Call the *CENTRAL* method for it...
    #----------------------------------------
    my $ret = $collect -> mainTask ();
    if ( $ret != 0 ) {
        $kiwi -> warning( "KIWICollect had runtime error." );
        $kiwi -> skipped ();
        kiwiExit ( $ret );
    }
    $kiwi->info( "KIWICollect completed successfully." );
    $kiwi->done();
    kiwiExit (0);
    return;
}

main();

# vim: set noexpandtab:
