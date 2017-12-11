# -*- perl -*-
# t/001-load.t - check module loading and create testing directory
use strict;
use warnings;

use Test::More tests => 12;
use File::Temp ( qw| tempdir |);
#use Data::Dump ( qw| dd pp | );

BEGIN { use_ok( 'Test::Against::Blead' ); }

my $tdir = tempdir(CLEANUP => 1);
my $self;

{
    local $@;
    eval { $self = Test::Against::Blead->new([]); };
    like($@, qr/Argument to constructor must be hashref/,
        "new: Got expected error message for non-hashref argument");
}

{
    local $@;
    eval { $self = Test::Against::Blead->new({}); };
    like($@, qr/Hash ref must contain 'application_dir' element/,
        "new: Got expected error message; 'application_dir' element absent");
}

{
    local $@;
    my $phony_dir = '/foo';
    eval { $self = Test::Against::Blead->new({ application_dir => $phony_dir }); };
    like($@, qr/Could not locate $phony_dir/,
        "new: Got expected error message; 'application_dir' not found");
}

$self = Test::Against::Blead->new( {
    application_dir         => $tdir,
} );
isa_ok ($self, 'Test::Against::Blead');

my $top_dir = $self->get_application_dir;
is($top_dir, $tdir, "Located top-level directory $top_dir");

for my $dir ( qw| src testing results | ) {
    my $fdir = File::Spec->catdir($top_dir, $dir);
    ok(-d $fdir, "Located $fdir");
}
ok(-d $self->get_src_dir, "Got src directory");
ok(-d $self->get_testing_dir, "Got testing directory");
ok(-d $self->get_results_dir, "Got results directory");
