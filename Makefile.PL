use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'XML::Parser::Style::Elemental',
    'VERSION_FROM'	=> 'lib/XML/Parser/Style/Elemental.pm', # finds $VERSION
    'PREREQ_PM'		=> { XML::Parser }, # e.g., Module::Name => 1.1
);
