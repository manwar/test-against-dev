use 5.14.0;
use Devel::CheckBin;
check_bin('git');
if ($^O =~ m/mswin32/i) {
    print STDERR "NA: Not yet tested on Windows\n";
    exit 0;
}
use ExtUtils::MakeMaker;

my $mm_ver = ExtUtils::MakeMaker->VERSION;

WriteMakefile(
    NAME         => 'Test::Against::Dev',
    VERSION_FROM => 'lib/Test/Against/Dev.pm',
    AUTHOR       => 'James E Keenan (jkeenan@cpan.org)',
    ABSTRACT     => 'Test CPAN modules against Perl dev releases',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
        'Devel::CheckBin' => 0,
    },
    MIN_PERL_VERSION => '5.14.0',
    PREREQ_PM    => {
                    # core
                    'Carp'                              => 0,
                    'File::Basename'                    => 0,
                    'File::Fetch'                       => 0,
                    'File::Path'                        => 2.15,
                    'File::Spec'                        => 0,
                    'File::Temp'                        => 0,
                    # non-core
                    'Archive::Tar'                      => 0,
                    'CPAN::cpanminus::reporter::RetainReports' => 0.05,
                    'Data::Dump'                        => 0,
                    'JSON'                              => 0,
                    'Path::Tiny'                        => 0,
                    'Perl::Download::FTP'               => 0.03,
                    'Text::CSV_XS'                      => 0,
    },
    ( $mm_ver < 6.63_03 ? 'BUILD_REQUIRES' : 'TEST_REQUIRES' ) =>  {
                     'Test::Simple'                     => 0.44,
                     'Capture::Tiny'                    => 0,
                     'Test::RequiresInternet'           => 0,
    },
   ($mm_ver < 6.46 ? () : (META_MERGE => {
        'meta-spec' => { version => 2 },
        dynamic_config => 1,
        resources => {
            homepage => 'http://thenceforward.net/perl/modules/Test-Against-Dev/',
            repository => {
                url => 'https://github.com/jkeenan/test-against-dev.git',
                web => 'https://github.com/jkeenan/test-against-dev',
                type => 'git',
            },
            bugtracker => {
                web => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Test-Against-Dev',
            },
        },
    })),
    ($mm_ver < 6.31 ? () : (LICENSE => 'perl_5')),
);
