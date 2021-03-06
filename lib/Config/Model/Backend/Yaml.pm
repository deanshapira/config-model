#
# This file is part of Config-Model
#
# This software is Copyright (c) 2005-2017 by Dominique Dumont.
#
# This is free software, licensed under:
#
#   The GNU Lesser General Public License, Version 2.1, February 1999
#

package Config::Model::Backend::Yaml;
$Config::Model::Backend::Yaml::VERSION = '2.101';
use Carp;
use strict;
use warnings;
use Config::Model::Exception;
use File::Path;
use Log::Log4perl qw(get_logger :levels);

use base qw/Config::Model::Backend::Any/;
use YAML::Any;

my $logger = get_logger("Backend::Yaml");

sub suffix { return '.yml'; }

sub single_element {
    my $self = shift;

    my @elts = $self->node->children;
    return undef if @elts != 1;

    my $obj = $self->node->fetch_element($elts[0]);
    my $type = $obj->get_type;
    return $type =~ /^(list|hash)$/ ? $obj : undef ;
}

sub read {
    my $self = shift;
    my %args = @_;

    # args is:
    # object     => $obj,         # Config::Model::Node object
    # root       => './my_test',  # fake root directory, userd for tests
    # config_dir => /etc/foo',    # absolute path
    # file       => 'foo.conf',   # file name
    # file_path  => './my_test/etc/foo/foo.conf'
    # io_handle  => $io           # IO::File object
    # check      => yes|no|skip

    return 0 unless defined $args{io_handle};    # no file to read

    # load yaml file
    my $yaml = join( '', $args{io_handle}->getlines );

    # convert to perl data
    my $perl_data = Load $yaml ;
    if ( not defined $perl_data ) {
        $logger->warn("No data found in YAML file $args{file_path}");
        return 1;
    }

    my $target = $self->single_element // $self->node ;

    # load perl data in tree
    $target->load_data( data => $perl_data, check => $args{check} || 'yes' );
    return 1;
}

sub write {
    my $self = shift;
    my %args = @_;

    # args is:
    # object     => $obj,         # Config::Model::Node object
    # root       => './my_test',  # fake root directory, userd for tests
    # config_dir => /etc/foo',    # absolute path
    # file       => 'foo.conf',   # file name
    # file_path  => './my_test/etc/foo/foo.conf'
    # io_handle  => $io           # IO::File object
    # check      => yes|no|skip

    croak "Undefined file handle to write"
        unless defined $args{io_handle};

    my $target = $self->single_element // $self->node ;

    my $perl_data = $target->dump_as_data( full_dump => $args{full_dump} // 0);

    my $yaml = Dump $perl_data ;

    $args{io_handle}->print($yaml);

    return 1;
}

1;

# ABSTRACT: Read and write config as a YAML data structure

__END__

=pod

=encoding UTF-8

=head1 NAME

Config::Model::Backend::Yaml - Read and write config as a YAML data structure

=head1 VERSION

version 2.101

=head1 SYNOPSIS

 use Config::Model ;
 use Data::Dumper ;

 # define configuration tree object
 my $model = Config::Model->new ;
 $model ->create_config_class (
    name => "MyClass",
    element => [ 
        [qw/foo bar/] => { 
            type => 'leaf',
            value_type => 'string'
        },
        baz => { 
            type => 'hash',
            index_type => 'string' ,
            cargo => {
                type => 'leaf',
                value_type => 'string',
            },
        },
    ],
  read_config  => [
                    { backend => 'yaml' , 
                      config_dir => '/tmp',
                      file  => 'foo.yml',
                      auto_create => 1,
                    }
                  ],
 ) ;

 my $inst = $model->instance(root_class_name => 'MyClass' );

 my $root = $inst->config_root ;

 my $steps = 'foo=yada bar="bla bla" baz:en=hello
             baz:fr=bonjour baz:hr="dobar dan"';
 $root->load( steps => $steps ) ;
 $inst->write_back ;

Now, C</tmp/foo.yml> contains:

 ---
 bar: bla bla
 baz:
   en: hello
   fr: bonjour
   hr: dobar dan
 foo: yada

=head1 DESCRIPTION

This module is used directly by L<Config::Model> to read or write the
content of a configuration tree written with YAML syntax in
C<Config::Model> configuration tree.

Note:

=over 4

=item *

Undefined values are skipped for list element. I.e. if a
list element contains C<('a',undef,'b')>, the data structure
contains C<'a','b'>.

=item *

YAML file is not created (and may be deleted) when no data is to be
written.

=back

=head2 Class with only one hash element

If the root node contains a single hash or list element, only the
content of this hash is written in a YAML file.

For example, if a class contains:

      element => [
        baz => {
            type => 'hash',
            index_type => 'string' ,
            cargo => {
                type => 'leaf',
                value_type => 'string',
            },
        },

If the configuration is loaded with:

 $root->load("baz:one=un baz:two=deux")

Then the written YAML file does B<not> show C<baz>:

 ---
 one: un
 two: deux

Likewise, a YAML file for a class with a single list C<baz> element
would be written with:

 ---
 - un
 - deux

=head1 CONSTRUCTOR

=head2 new ( node => $node_obj, name => 'yaml' ) ;

Inherited from L<Config::Model::Backend::Any>. The constructor is
called by L<Config::Model::BackendMgr>.

=head2 read ( io_handle => ... )

Of all parameters passed to this read call-back, only C<io_handle> is
used. This parameter must be L<IO::File> object already opened for
read. 

It can also be undef. In which case C<read()> returns 0.

When a file is read,  C<read()> returns 1.

=head2 write ( io_handle => ... )

Of all parameters passed to this write call-back, only C<io_handle> is
used. This parameter must be L<IO::File> object already opened for
write. 

C<write()> returns 1.

=head1 AUTHOR

Dominique Dumont, (ddumont at cpan dot org)

=head1 SEE ALSO

L<Config::Model>, 
L<Config::Model::BackendMgr>, 
L<Config::Model::Backend::Any>, 

=head1 AUTHOR

Dominique Dumont

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2005-2017 by Dominique Dumont.

This is free software, licensed under:

  The GNU Lesser General Public License, Version 2.1, February 1999

=cut
