#!/usr/bin/env perl
#############################################################################
##
## Copyright (C) 2012 Digia Plc and/or its subsidiary(-ies).
## Contact: http://www.qt-project.org/legal
##
## This file is part of the Qt Toolkit.
##
## $QT_BEGIN_LICENSE:LGPL$
## Commercial License Usage
## Licensees holding valid commercial Qt licenses may use this file in
## accordance with the commercial license agreement provided with the
## Software or, alternatively, in accordance with the terms contained in
## a written agreement between you and Digia.  For licensing terms and
## conditions see http://qt.digia.com/licensing.  For further information
## use the contact form at http://qt.digia.com/contact-us.
##
## GNU Lesser General Public License Usage
## Alternatively, this file may be used under the terms of the GNU Lesser
## General Public License version 2.1 as published by the Free Software
## Foundation and appearing in the file LICENSE.LGPL included in the
## packaging of this file.  Please review the following information to
## ensure the GNU Lesser General Public License version 2.1 requirements
## will be met: http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
##
## In addition, as a special exception, Digia gives you certain additional
## rights.  These rights are described in the Digia Qt LGPL Exception
## version 1.1, included in the file LGPL_EXCEPTION.txt in this package.
##
## GNU General Public License Usage
## Alternatively, this file may be used under the terms of the GNU
## General Public License version 3.0 as published by the Free Software
## Foundation and appearing in the file LICENSE.GPL included in the
## packaging of this file.  Please review the following information to
## ensure the GNU General Public License version 3.0 requirements will be
## met: http://www.gnu.org/copyleft/gpl.html.
##
##
## $QT_END_LICENSE$
##
#############################################################################

=head1 NAME

nodecfg.pl - external node classifier for qtqa puppet setup

=head1 SYNOPSIS

  # on first run, to configure the setup for this machine:
  nodecfg.pl -interactive

This script configures a machine for usage with the qtqa puppet setup.
It is used as a puppet External Node Classifier script, and may be
invoked interactively to aid in the initial setup of nodes.

=cut
use v5.10;
use strict;
use warnings;

use File::Spec::Functions;
use FindBin;
use Getopt::Long;
use IO::Handle;
use English qw( -no_match_vars );
use Pod::Usage;
use Net::Domain qw( hostname );
use feature 'state';

# directory containing files relating to this script
my $CFG_DIR = catfile( $FindBin::Bin, 'nodecfg' );

# filename generated by -interactive option
my $INTERACTIVE_CFG_FILE = catfile( $CFG_DIR, '10-config.yaml' );

# log file (overwritten at each run)
my $LOG_FILE = catfile( $CFG_DIR, 'nodecfg.log' );
my $PARAMETERS_FOR_TESTER = (
          [
                testuser => {
                    doc => qq{Username of the account used for all testing; \n}
                          .qq{this should be an account which is not used for any other\n}
                          .qq{activities on this machine.},
                    default => 'qt',
                },

                network_test_server_ip => {
                    doc => qq{IPv4 address of the network test server (qt-test-server.qt-test-net) \n}
                          .qq{to be used while running autotests on this host; leave blank if you don't\n}
                          .qq{have a server, in which case many network tests will skip},
                    default => q{},
                },

                qt_gerrit_mirror => {
                    doc => qq{Base URL of a local mirror of Qt's gerrit (codereview.qt-project.org). \n}
                          .qq{This will be used as the 'qt-gerrit-mirror' git alias to speed up git \n}
                          .qq{operations while testing. \n\n}
                          .qq{The base URL will have Qt module names appended; for example: \n}
                          .qq{ "git://git.example.com/" => "git://git.example.com/qt/qtbase" \n\n}
                          .qq{Leave blank if you don't have a mirror},
                    default => q{},
                },

                jenkins_enabled => {
                    doc => qq{Run a Jenkins slave on this host?},
                    type => 'bool',
                    default => 'n',
                    child => [
                        jenkins_server => {
                            doc => qq{Jenkins server URL (e.g. http://jenkins.example.com/)},
                        },
                        jenkins_slave_name => {
                            doc => qq{Name of this Jenkins slave (must be preconfigured on server)},
                            default => hostname(),
                        }
                    ],
                },

                vmware_enabled => {
                    doc => qq{This host is VMWare virtual machine?},
                    type => 'bool',
                    default => 'y',
                },

                (($OSNAME =~ m{linux}i) ?
                    (icecc_enabled => {
                        doc => 'Use icecream distributed compilation tool?',
                        default => 'y',
                        type => 'bool',
                        child => [
                            icecc_scheduler_host => {
                                doc => qq{Icecream scheduler hostname; leave empty for autodiscovery, \n}
                                      .qq{which usually works if the scheduler is on the same LAN and IP broadcast \n}
                                      .qq{is working.},
                                default => q{},
                            }
                        ]
                    })
                    :
                    ()
                ),

                (($OSNAME =~ m{darwin}i) ?
                    (distcc_enabled => {
                        doc => 'Use distcc distributed compilation tool?',
                        default => 'y',
                        type => 'bool',
                        child => [
                            distcc_hosts => {
                                doc => qq{Distcc host specification; used for distributed compilation. \n}
                                      .qq{List of whitespace separated hostnames and other distcc specific options. \n}
                                      .qq{e.g., --randomize ci-mac-mini-01 ci-mac-mini-02 ci-mac-mini-03},
                                default => 'localhost',
                            }
                        ]
                    })
                    :
                    ()
                ),
            ],
);
# Data used for interactive setup.
# Would be nice to automatically extract these from the manifests (magic comments?)
my %INTERACTIVE = (
    parameters => [
        location => {
            doc => qq{Location for CI machines.\n}
                  .qq{The location variable is used to customize certain puppet configurations.\n\n}
                  .qq{The location is typically something like: "Oslo", "Brisbane" or "Digia". \n\n},

            default => q{},
        },
        qtgitreadonly => {
            doc => qq{Base URL of Qt's git repositories (git://qt.gitorious.org/). \n}
                  .qq{This will be used as the 'qtgitreadonly' alias for git \n}
                  .qq{operations while testing. \n\n}
                  .qq{The base URL will have Qt module names appended; for example: \n}
                  .qq{ "git://git.example.com/" => "git://git.example.com/qt/qtbase" \n\n},
            default => 'git://qt.gitorious.org/',
        },
        input => {
            doc => qq{Base HTTP URL where large files are hosted (tarballs etc) \n}
                  .qq{These files are all publicly available but you'll have to host them \n}
                  .qq{in your own mirror. \n\n}
                  .qq{The base HTTP URL can be for example: "http://replace-me.example.com/input". \n\n},

            default => q{},
        },
        email => {
            doc => qq{E-mail address where scripts run on this client node can send \n}
                  .qq{notifications in case of errors. \n\n}
                  .qq{The address can be for example: "nodes-in-ci\@mail.com". \n\n},

            default => q{},
        },
        smtp => {
            doc => qq{SMTP server address which this client node can use to send e-mails. \n\n}
                  .qq{The address can be for example: "smtp.mail.com". \n\n},

            default => q{},
        },
    ],

    classes => {

        ci_tester => {
            doc => 'Qt Project CI tester, performing Qt compilation and autotests',
            parameters => $PARAMETERS_FOR_TESTER
        },

        bb_tester => {
            doc => 'BlackBery CI tester, performing Qt compilation and autotests',
            parameters => $PARAMETERS_FOR_TESTER
        },

        packaging_tester => {
            doc => 'Qt Project Packaging tester, performing Qt compilation and autotests',
            parameters => $PARAMETERS_FOR_TESTER
        },

        ci_server => {
            doc => "Qt Project CI system server (Jenkins <-> Gerrit integration)"
        },

        packaging_server => {
            doc => "Qt Project packaging server"
        },

        network_test_server => {
            doc => "Network test server, used for some QtNetwork autotests (qt-test-server.qt-test-net)"
        },

    },
);

# like IO::Prompt::prompt, but supports only the following subset:
#  -integer
#  -default <value>
#  -yes
sub prompt
{
    my $text = shift;

    my $match;
    my $match_error;
    my $default;
    my $yes;
    while (my $arg = shift) {
        if ($arg eq '-integer') {
            $match = qr{\A[0-9]+\z};
            $match_error = 'input is not a valid positive integer';
        } elsif ($arg eq '-default') {
            $default = shift;
        } elsif ($arg eq '-yes') {
            $yes = 1;
        } else {
            $text .= $arg;
        }
    }

    while (1) {
        local $OUTPUT_AUTOFLUSH = 1;
        print $text;

        my $in = <STDIN>;
        if (!defined( $in ) && eof( STDIN )) {
            print_interactive( "STDIN closed - aborting.\n" );
            exit 3;
        }
        chomp $in;
        $in ||= $default || q{};

        if ($match && $in !~ $match) {
            print "$match_error\n";
            next;
        }

        if ($yes) {
            if ($in =~ m{\A[yY]}) {
                return 1;
            }
            return 0;
        }


        return $in;
    }

    return;
}

# Given a set of @choices, presents them to the user and returns the array index chosen.
# $text is a header printed immediately prior to the menu.
sub prompt_menu_idx
{
    my ($text, @choices) = @_;

    print "$text\n\n";

    my $i = 1;
    foreach my $c (@choices) {
        print "  ($i) $c\n";
        ++$i;
    }
    print "\n";

    while (1) {
        my $selected = prompt( '? ', '-integer' );
        if ($selected >= 1 && $selected < $i) {
            # user input is 1-based, array index is 0-based
            return $selected - 1;
        }
        print "Invalid input '$selected', please try again.\n";
    }

    return;
}

# Open the log file and return a filehandle for writing,
# or warn and return nothing on failure.
sub open_log
{
    my $fh;
    if (open($fh, '>', $LOG_FILE)) {
        return $fh;
    }
    warn "Unable to log to $LOG_FILE: $!";
    return;
}

# Print a message to the log file, which is opened on first use.
# If the log file can't be opened, prints to STDERR instead.
sub print_log
{
    state $log_fh = open_log();
    if ($log_fh) {
        $log_fh->printflush( @_ );
    } else {
        warn @_;
    }
    return;
}

# Print a message both to STDOUT and to the log file.
sub print_interactive
{
    print_log( @_ );

    local $OUTPUT_AUTOFLUSH = 1;
    print @_;

    return;
}

# Return the entire content of the file given by $filename, or die on error
sub read_file
{
    my ($filename) = @_;
    open( my $fh, '<', $filename ) || die "open $filename for read: $!";
    local $INPUT_RECORD_SEPARATOR = undef;
    my $text = <$fh>;
    close( $fh );
    return $text;
}

# Write the given $text into the file given by $filename, or die on error;
# the file is created if necessary, and replaced if it already exists.
sub write_file
{
    my ($filename, $text) = @_;
    open( my $fh, '>', $filename ) || die "open $filename for write: $!";
    print $fh $text;
    close( $fh ) || die "close $filename after write: $!";
    return;
}

# Read all configuration files from the config directory and return the
# resulting configuration string (which should be a YAML document).
sub read_config
{
    my @texts;

    my @files = sort glob catfile( $CFG_DIR, '*.yaml' );
    foreach my $file (@files) {
        print_log( "Reading $file ...\n" );
        my $text;
        eval {
            $text = read_file( $file );
        };
        if (my $error = $EVAL_ERROR) {
            print_log( "Error reading from $file: $error" );
            next;
        }
        push @texts, $text;
    }
    print_log( "Config read.\n" );

    return join( "\n", @texts );
}

# Check if a config file exists at $filename; if so, prompt if the user
# wants to continue.
sub check_existing_config
{
    my ($filename) = @_;

    return unless -e $filename;

    my $current_cfg = read_file( $filename );

    print "Warning: $filename already exists.\n"
         ."If you continue, this configuration will be overwritten:\n\n"
         ."$current_cfg\n\n";

    if (prompt( 'Continue (y/n) ? ' ) ne 'y') {
        print "Aborting.\n";
        exit 2;
    }

    print_interactive "Will overwrite existing configuration.\n";
    return;
}

# Prompt for selection of a class.
sub select_class
{
    my ($in, $out) = @_;

    print "\n";
    my @classes = sort keys %{ $in->{ classes } };
    my $selected = prompt_menu_idx(
        'Select which of the following best describes the purpose of this host:',
        (map { "$_ - $in->{ classes }{ $_ }{ doc }" } @classes)
    );

    my $class = $classes[$selected];
    $out->{ classes }{ $class } = {};

    return $class;
}

# Prompt for a parameter value.
# If the parameter has child parameters, they will also be prompted, recursively.
sub configure_param
{
    my ($name, $in, $out, $indent) = @_;
    $indent ||= q{};

    my $doc = $in->{ doc };
    $doc =~ s{^}{$indent}mg;

    my $default = $in->{ default };
    my $type = $in->{ type };

    print "\n$doc\n";

    my $value = prompt(
        "$indent  $name",

        defined($default) ? (
            " [$default]",
            -default => $default,
        ) : (),

        ($type && $type eq 'bool') ? ('-yes') : (),

        ' ? ',
    );

    if ($type && $type eq 'bool') {
        $value &&= 'true';
        $value ||= 'false';
    }

    $out->{ $name } = $value;

    # handle child params, if any
    if ($type && $type eq 'bool' && $value eq 'true') {
        my @params = @{ $in->{ child } || [] };
        while (my ($childname, $childdata) = splice( @params, 0, 2 )) {
            configure_param(
                $childname,
                $childdata,
                $out,
                "$indent  ",
            );
        }
    }

    return;
}

# Given a generated config object, serializes it as YAML and returns it.
# The YAML formatter is quite basic and may give incorrect results for
# complex input. Arrays, hashes and single-line strings are OK.
sub serialize_config
{
    my ($data, $indent) = @_;
    $indent ||= q{};

    my $type = ref($data);
    if (!$type) {
        # special case to differentiate an empty string from no value
        if ($data eq q{}) {
            return q{ ""};
        }
        return " $data";
    }

    my $out = "\n";

    if ($type eq 'ARRAY') {
        foreach my $v (@{ $data }) {
            $out .= "$indent- " . serialize_config( $v, "$indent  " ) . "\n";
        }
        return $out;
    }

    my @keys = sort keys %{ $data };
    foreach my $k (@keys) {
        my $v = $data->{ $k };
        $out .= "$indent$k:" . serialize_config( $v, "$indent  " ) . "\n";
    }

    return $out;
}

# Entry point to -interactive mode
sub run_interactive
{
    my $file = $INTERACTIVE_CFG_FILE;

    print_interactive <<"EOF";
Configuring interactively.

This script will generate the following configuration file:

  $file

The usage of this script is optional; it is intended to give a quick start
to configuring a machine for the most common use-cases.
It's fine to instead create the configuration by hand, or copy a file from
another machine, or skip this for now and come back later.

Press CTRL+C to abort this interactive process at any time.

EOF

    check_existing_config( $file );

    my %config;

    print_interactive "Configuring global parameters\n";

    $config{ parameters } = {};

    my @globalparams = @{ $INTERACTIVE{ parameters } || [] };
    while (my ($name, $data) = splice( @globalparams, 0, 2 )) {
        configure_param(
            $name,
            $data,
            $config{ parameters },
        );
    }

    # choose a class
    my $class = select_class( \%INTERACTIVE, \%config );

    print_interactive "Configuring a node of class '$class'\n";

    my $classdata = $INTERACTIVE{ classes }{ $class };
    my @params = @{ $classdata->{ parameters } || [] };
    while (my ($name, $data) = splice( @params, 0, 2 )) {
        configure_param(
            $name,
            $data,
            $config{ classes }{ $class },
        );
    }

    my $text = serialize_config( \%config );
    $text =~ s{\A\s+}{};
    $text =~ s{\s+\z}{};

    my $displaytext = $text;
    $displaytext =~ s{^}{  }mg;

    print_interactive "\n\nConfiguration completed:\n\n$displaytext\n\n";
    if (!prompt( 'Save (y/n) [y] ? ', '-yes', -default => 'y' )) {
        print_interactive "Not saving.\n";
        return;
    }

    write_file( $file, "$text\n" );

    print_interactive
        "Configuration saved to $file.\n"
       ."To reconfigure, run: $FindBin::Bin/$FindBin::Script -interactive\n";

    return;
}

sub run
{
    my ($node) = @_;

    if ($node && $node eq '-interactive') {
        return run_interactive();
    }

    if (!$node || $node =~ m{\A-}) {
        pod2usage( 2 );
    }

    print_log( "Invoked for node $node\n" );
    if (my $config = read_config( )) {
        print "$config\n";
    } else {
        print_log( "No configuration is set, try: nodecfg.pl -interactive\n" );

        # Simulate a node which is known, but empty, so that legacy definitions in nodes.pp
        # can still be processed.
        print "classes:\n\n";
        print "parameters:\n";
    }
    return;
}

run( @ARGV ) unless caller;
1;
