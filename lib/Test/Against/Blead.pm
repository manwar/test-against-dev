package Test::Against::Blead;
use strict;
use 5.10.1;
our $VERSION = '0.01';
use Carp;
use Cwd;
use File::Fetch;
use File::Path ( qw| make_path | );
use File::Spec;
use File::Temp ( qw| tempdir | );
use Perl::Download::FTP;

# What args must be passed to constructor?
# application top-level directory
# Constructor will get path to top-level directory for application,
# compose names of other directories in the tree, verify they exist or create
# them as needed.

sub new {
    my ($class, $args) = @_;

    croak "Argument to constructor must be hashref"
        unless ref($args) eq 'HASH';
    croak "Hash ref must contain 'application_dir' element"
        unless $args->{application_dir};
    croak "Could not locate $args->{application_dir}"
        unless (-d $args->{application_dir});

    my $data;
    for my $k (keys %{$args}) {
        $data->{$k} = $args->{$k};
    }

    for my $dir (qw| src testing results |) {
        my $fdir = File::Spec->catdir($data->{application_dir}, $dir);
        unless (-d $fdir) { make_path($fdir, { mode => 0755 }); }
        croak "Could not locate $fdir" unless (-d $fdir);
        $data->{"${dir}_dir"} = $fdir;
    }

    $data->{release_pattern} = qr/^perl-5\.\d+\.\d{1,2}$/;
    return bless $data, $class;
}

sub get_application_dir {
    my $self = shift;
    return $self->{application_dir};
}

sub get_src_dir {
    my $self = shift;
    return $self->{src_dir};
}

sub get_testing_dir {
    my $self = shift;
    return $self->{testing_dir};
}

sub get_results_dir {
    my $self = shift;
    return $self->{results_dir};
}

sub perform_tarball_download {
    my ($self, $args) = @_;
    croak "perform_tarball_download: Must supply hash ref as argument"
        unless ref($args) eq 'HASH';
    my $verbose = delete $args->{verbose} || '';
    my $mock = delete $args->{mock} || '';
    my %eligible_args = map { $_ => 1 } ( qw|
        host hostdir release compression workdir
    | );
    for my $k (keys %$args) {
        croak "perform_tarball_download: '$k' is not a valid element"
            unless $eligible_args{$k};
    }
    croak "perform_tarball_download: '$args->{release}' does not conform to pattern"
        unless $args->{release} =~ m/$self->{release_pattern}/;

    my %eligible_compressions = map { $_ => 1 } ( qw| gz bz2 xz | );
    croak "perform_tarball_download: '$args->{compression}' is not a valid compression format"
        unless $eligible_compressions{$args->{compression}};

    croak "Could not locate '$args->{workdir}' for purpose of downloading tarball and building perl"
        if (exists $args->{workdir} and (! -d $args->{workdir}));

    $self->{$_} = $args->{$_} for keys %$args;

    $self->{tarball} = "$self->{release}.tar.$self->{compression}";

    my $this_release_dir = File::Spec->catdir($self->get_testing_dir(), $self->{release});
    unless (-d $this_release_dir) { make_path($this_release_dir, { mode => 0755 }); }
    croak "Could not locate $this_release_dir" unless (-d $this_release_dir);
    $self->{release_dir} = $this_release_dir;

    my $ftpobj = Perl::Download::FTP->new( {
        host        => $self->{host},
        dir         => $self->{hostdir},
        Passive     => 1,
        verbose     => $verbose,
    } );

    unless ($mock) {
        if (! $self->{workdir}) {
            $self->{restore_to_dir} = cwd();
            $self->{workdir} = tempdir(CLEANUP => 1);
        }
        if ($verbose) {
            say "Beginning FTP download (this will take a few minutes)";
            say "Perl configure-build-install cycle will be performed in $self->{workdir}";
        }
        my $tarball_path = $ftpobj->get_specific_release( {
            release         => $self->{tarball},
            path            => $self->{workdir},
        } );
        unless (-f $tarball_path) {
            croak "Tarball $tarball_path not found: $!";
        }
        else {
            say "Path to tarball is $tarball_path" if $verbose;
            $self->{tarball_path} = $tarball_path;
            return ($tarball_path, $self->{workdir});
        }
    }
    else {
        say "Mocking; not really attempting FTP download" if $verbose;
        return 1;
    }
}

sub get_release_dir {
    my $self = shift;
    if (! defined $self->{release_dir}) {
        croak "release directory has not yet been defined; run perform_tarball_download()";
    }
    else {
        return $self->{release_dir};
    }
}

sub access_configure_command {
    my ($self, $arg) = @_;
    my $cmd;
    if (length $arg) {
        $cmd = $arg;
    }
    else {
        $cmd = "sh ./Configure -des -Dusedevel -Uversiononly -Dprefix=";
        $cmd .= $self->get_release_dir;
        $cmd .= " -Dman1dir=none -Dman3dir=none";
    }
    $self->{configure_command} = $cmd;
}

sub access_make_install_command {
    my ($self, $arg) = @_;
    my $cmd;
    if (length $arg) {
        $cmd = $arg;
    }
    else {
        $cmd = "make install"
    }
    $self->{make_install_command} = $cmd;
}

sub configure_build_install_perl {
    my ($self, $args) = @_;
    my $cwd = cwd();
    $args //= {};
    croak "perform_tarball_download: Must supply hash ref as argument"
        unless ref($args) eq 'HASH';
    my $verbose = delete $args->{verbose} || '';

    # What I want in terms of verbose output:
    # 0: No verbose output from Test::Against::Blead
    #    Minimal output from tar, Configure, make
    #    (tar xzf; Configure, make 1>/dev/null
    # 1: Verbose output from Test::Against::Blead
    #    Minimal output from tar, Configure, make
    #    (tar xzf; Configure, make 1>/dev/null
    # 2: Verbose output from Test::Against::Blead
    #    Verbose output from tar ('v')
    #    Regular output from Configure, make

    # Use default configure and make install commands unless an argument has
    # been passed.
    my $acc = $self->access_configure_command($args->{configure_command} || '');
    my $mic = $self->access_make_install_command($args->{make_install_command} || '');
    unless ($verbose > 1) {
        $self->access_configure_command($acc . " 1>/dev/null");
        $self->access_make_install_command($mic . " 1>/dev/null");
    }

    chdir $self->{workdir} or croak "Unable to change to $self->{workdir}";
    my $untar_command = ($verbose > 1) ? 'tar xzvf' : 'tar xzf';
    system(qq|$untar_command $self->{tarball_path}|)
        and croak "Unable to untar $self->{tarball_path}";
    say "Tarball has been untarred into ", File::Spec->catdir($self->{workdir}, $self->{release})
        if $verbose;
    my $build_dir = $self->{release};
    chdir $build_dir or croak "Unable to change to $build_dir";
    say "Configuring perl with '$self->{configure_command}'" if $verbose;
    system(qq|$self->{configure_command}|)
        and croak "Unable to configure with '$self->{configure_command}'";
    say "Building and installing perl with '$self->{make_install_command}'" if $verbose;
    system(qq|$self->{make_install_command}|)
        and croak "Unable to build and install with '$self->{make_install_command}'";
    my $rdir = $self->get_release_dir();
    my $bindir = File::Spec->catdir($rdir, 'bin');
    my $libdir = File::Spec->catdir($rdir, 'lib');
    my $this_perl = File::Spec->catfile($bindir, 'perl');
    croak "Could not locate '$bindir'" unless (-d $bindir);
    croak "Could not locate '$libdir'" unless (-d $libdir);
    croak "Could not locate '$this_perl'" unless (-f $this_perl);
    $self->{bindir} = $bindir;
    $self->{libdir} = $libdir;
    $self->{this_perl} = $this_perl;
    chdir $cwd or croak "Unable to change back to $cwd";
    if ($self->{restore_to_dir}) {
        chdir $self->{restore_to_dir} or croak "Unable to change back to $self->{restore_to_dir}";
    }
    return $this_perl;
}

sub get_bindir {
    my $self = shift;
    if (! defined $self->{bindir}) {
        croak "bin directory has not yet been defined; run configure_build_install_perl()";
    }
    else {
        return $self->{bindir};
    }
}

sub get_libdir {
    my $self = shift;
    if (! defined $self->{libdir}) {
        croak "lib directory has not yet been defined; run configure_build_install_perl()";
    }
    else {
        return $self->{libdir};
    }
}

sub fetch_cpanm {
    my ($self, $args) = @_;
    $args //= {};
    croak "perform_tarball_download: Must supply hash ref as argument"
        unless ref($args) eq 'HASH';
    my $verbose = delete $args->{verbose} || '';
    my $uri = (exists $args->{uri} and length $args->{uri})
        ? $args->{uri}
        : 'http://cpansearch.perl.org/src/MIYAGAWA/App-cpanminus-1.7043/bin/cpanm';

    my $cpanm_dir = File::Spec->catdir($self->get_release_dir(), '.cpanm');
    unless (-d $cpanm_dir) { make_path($cpanm_dir, { mode => 0755 }); }
    croak "Could not locate $cpanm_dir" unless (-d $cpanm_dir);
    $self->{cpanm_dir} = $cpanm_dir;

    say "Fetching 'cpanm' from $uri" if $verbose;
    my $ff = File::Fetch->new(uri => $uri);
    my ($scalar, $where);
    $where = $ff->fetch( to => \$scalar );
    croak "Did not download 'cpanm'" unless (-f $where);
    open my $IN, '<', \$scalar or croak "Unable to open scalar for reading";
    my $this_cpanm = File::Spec->catfile($self->{bindir}, 'cpanm');
    open my $OUT, '>', $this_cpanm or croak "Unable to open $this_cpanm for writing";
    while (<$IN>) {
        chomp $_;
        say $OUT $_;
    }
    close $OUT or croak "Unalbe to close $this_cpanm after writing";
    close $IN or croak "Unable to close scalar after reading";
    unless (-f $this_cpanm) {
        croak "Unable to locate '$this_cpanm'";
    }
    else {
        say "Installed '$this_cpanm'";
    }
    my $cnt = chmod 0755, $this_cpanm;
    croak "Unable to make '$this_cpanm' executable" unless $cnt;
    $self->{this_cpanm} = $this_cpanm;
}

sub get_cpanm_dir {
    my $self = shift;
    if (! defined $self->{cpanm_dir}) {
        croak "cpanm directory has not yet been defined; run fetch_cpanm()";
    }
    else {
        return $self->{cpanm_dir};
    }
}

sub setup_results_directories {
    my $self = shift;
    croak "Perl release not yet defined" unless $self->{release};
    my $vresultsdir = File::Spec->catdir($self->get_results_dir, $self->{release});
    my $buildlogsdir = File::Spec->catdir($vresultsdir, 'buildlogs');
    my $analysisdir = File::Spec->catdir($vresultsdir, 'analysis');
    my $storagedir = File::Spec->catdir($vresultsdir, 'storage');
    my @created = make_path( $vresultsdir, $buildlogsdir, $analysisdir, $storagedir,
        { mode => 0755 });
    for my $dir (@created) { croak "$dir not found" unless -d $dir; }
    return scalar(@created);
}




1;

