# -*- perl -*-
# t/001-load.t - check module loading and create testing directory
use strict;
use warnings;

use Test::More tests => 9;
use File::Temp ( qw| tempdir |);
#use Data::Dump ( qw| dd pp | );

BEGIN { use_ok( 'Test::Against::Blead' ); }

my $tdir = tempdir(CLEANUP => 1);
my $self;

$self = Test::Against::Blead->new( {
    application_dir         => $tdir,
} );
isa_ok ($self, 'Test::Against::Blead');
#pp($self);

my $top_dir = $self->get_application_dir;
is($top_dir, $tdir, "Located top-level directory $top_dir");

for my $dir ( qw| src testing results | ) {
    my $fdir = File::Spec->catdir($top_dir, $dir);
    ok(-d $fdir, "Located $fdir");
}
ok(-d $self->get_src_dir, "Got src directory");
ok(-d $self->get_testing_dir, "Got testing directory");
ok(-d $self->get_results_dir, "Got results directory");

