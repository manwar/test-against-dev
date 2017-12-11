# -*- perl -*-
# t/003-test-against-dev.t - download and install a perl, a cpanm
use strict;
use warnings;

use Test::More;
use File::Temp ( qw| tempdir |);
use Data::Dump ( qw| dd pp | );
use Capture::Tiny ( qw| capture_stdout capture_stderr | );
use Test::RequiresInternet ('ftp.funet.fi' => 21);
BEGIN { use_ok( 'Test::Against::Blead' ); }

my $tdir = tempdir(CLEANUP => 1);
my $self;

$self = Test::Against::Blead->new( {
    application_dir         => $tdir,
} );
isa_ok ($self, 'Test::Against::Blead');

my $host = 'ftp.funet.fi';
my $hostdir = '/pub/languages/perl/CPAN/src/5.0';

SKIP: {
    skip 'Live FTP download', 7
        unless $ENV{PERL_ALLOW_NETWORK_TESTING} and $ENV{PERL_AUTHOR_TESTING};

    my ($stdout, $stderr);
    my ($tarball_path, $workdir, $release_dir);
    note("Performing live FTP download of Perl tarball;\n  this may take a while.");
    $stdout = capture_stdout {
        ($tarball_path, $workdir) = $self->perform_tarball_download( {
            host                => $host,
            hostdir             => $hostdir,
            release             => 'perl-5.27.6',
            compression         => 'gz',
            verbose             => 1,
            mock                => 0,
        } );
    };
    ok($tarball_path, 'perform_tarball_download: returned true value');
    $release_dir = $self->get_release_dir();
    ok(-d $release_dir, "Located release dir: $release_dir");
    ok(-f $tarball_path, "Downloaded tarball: $tarball_path");
    ok(-d $workdir, "Located work directory: $workdir");
    like($stdout, qr/Beginning FTP download/s,
        "Got expected verbose output: starting download");
    like($stdout, qr/Perl configure-build-install cycle will be performed in $workdir/s,
        "Got expected verbose output: cycle location");
    like($stdout, qr/Path to tarball is $tarball_path/s,
        "Got expected verbose output: tarball path");
}

done_testing();