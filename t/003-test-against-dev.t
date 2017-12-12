# -*- perl -*-
# t/003-test-against-dev.t - download and install a perl, a cpanm
use strict;
use warnings;
use feature 'say';

use Test::More;
use Carp;
use File::Temp ( qw| tempdir |);
use Data::Dump ( qw| dd pp | );
use Capture::Tiny ( qw| capture_stdout capture_stderr | );
use Test::RequiresInternet ('ftp.funet.fi' => 21);
BEGIN { use_ok( 'Test::Against::Blead' ); }

#my $tdir = tempdir(CLEANUP => 1);
my $tdir = '/home/jkeenan/tmp/special';
my $self;

$self = Test::Against::Blead->new( {
    application_dir         => $tdir,
} );
isa_ok ($self, 'Test::Against::Blead');

my $host = 'ftp.funet.fi';
my $hostdir = '/pub/languages/perl/CPAN/src/5.0';

SKIP: {
    skip 'Live FTP download', 15
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

    my $this_perl = $self->configure_build_install_perl({ verbose => 1 });
    ok(-f $this_perl, "Installed $this_perl");
    my $this_cpanm = $self->fetch_cpanm( { verbose => 1 } );
    ok(-f $this_cpanm, "Installed $this_cpanm");
    ok(-e $this_cpanm, "'$this_cpanm' is executable");
    my $bindir = $self->get_bindir();
    ok(-d $bindir, "Located '$bindir/'");
    my $libdir = $self->get_libdir();
    ok(-d $libdir, "Located '$libdir/'");
    my $cpanm_dir = $self->get_cpanm_dir();
    ok(-d $cpanm_dir, "Located '$cpanm_dir/'");
    system(qq|$this_perl -I$self->{libdir} $this_cpanm List::Compare|)
        and croak "Unable to use 'cpanm' to install module List::Compare";
    my $hw = `$this_perl -I$self->{libdir} -MList::Compare -e 'print q|hello world|;'`;
    is($hw, 'hello world', "Got 'hello world' when -MList::Compare");
    my $lcv = qx|$this_perl -I$libdir -MList::Compare -E 'say \$List::Compare::VERSION;'|;
    chomp($lcv);
    like($lcv, qr/^\d\.\d\d$/, "Got \$List::Compare::VERSION $lcv");
    pp({ %{$self} });
    note("Status");
}

done_testing();
