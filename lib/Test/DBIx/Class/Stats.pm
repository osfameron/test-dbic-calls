package Test::DBIx::Class::Stats;
use parent 'Test::Builder::Module';
use Test::DBIx::Class::Stats::Profiler;

our $VERSION = 0.01;
our @EXPORT = qw( with_stats );

=head1 NAME

Test::DBIx::Class::Stats - test statistics about your DBIx::Class calls

=head1 SYNOPSIS

Run a subtest with a debugging object (L<Test::DBIx::Class::Stats::Profiler>) set to capture
the number of calls that have been made to the database. This may be useful to
check your assumptions about prefetching, etc.

    use Test::More;
    use Test::DBIx::Class::Stats;

    # if you are using Test::DBIx::Class or similar, we can get the 
    # database handle from the `Schema` method
    use Test::DBIx::Class;

    with_stats 'test 1', sub {
        my $stats = shift;

        my $rs = Schema->resultset('Foo')->search();
        is $stats->call_count, 0, 'No calls on preparing RS';

        my @foo = $rs->all;
        is $stats->call_count, 1, '1 call after preparing RS';
    };

    # alternatively, we can pass it in explicitly:
    
    my $db = Schema
    with_stats 'test 2', $db, sub {
        ...
    };

=head1 EXPORTED FUNCTIONS

=over 4

=item C<with_stats $name, [$db], $code>

The L<Test::DBIx::Class::Stats::Profiler> object is created for the database
and is passed to your code reference as its first and only argument.

If C<$db> is not passed, the caller's C<Schema> function will be called.  This
is designed to work with L<Test::DBIx::Class>.

=back

=cut

sub with_stats {
    my ($name, @args) = @_;

    my $subtest = pop @args;
    my $db = @args ? shift @args : caller->Schema;

    my $storage = $db->storage;
    my %old = (
        debug    => $storage->debug,
        debugobj => $storage->debugobj,
    );
    my $stats = Test::DBIx::Class::Stats::Profiler->new();
    $storage->debug(1);
    $storage->debugobj( $stats );

    subtest_with( "With stats: $name", $subtest, $stats );

    $storage->debug( $old{debug} );
    $storage->debugobj( $old{debugobj} );
}

# this is cargo-culted from TB->subtest.
# if https://github.com/Test-More/test-more/pull/395 is accepted
# this routine can be deleted, and `with_stats` can just call
# Test::Builder->new->subtest( "With stats: $name", $subtest, $stats );
# (PR accepted, but 1.001003 not yet released)
sub subtest_with {
    my ($name, $subtest, @args) = @_;
    my $tb = __PACKAGE__->builder;


    my $error;
    my $child;
    my $parent = {};
    {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        $child = $tb->child($name);
        Test::Builder::_copy( $tb, $parent );
        Test::Builder::_copy( $child, $tb );

        my $run_with = sub {
            $tb->note($name);
            $subtest->(@args);
            $tb->done_testing unless $tb->_plan_handled;
            1;
        };

        eval { $run_with->() } or $error = $@;

        Test::Builder::_copy( $tb, $child );
        Test::Builder::_copy( $parent, $tb );
        $tb->find_TODO(undef, 1, $child->{Parent_TODO});
        die $error if $error and !eval { $error->isa('Test::Builder::Exception') };

        local $Test::Builder::Level = $Test::Builder::Level + 1;
        my $finalize = $child->finalize;

        $tb->BAIL_OUT($child->{Bailed_Out_Reason}) if $child->{Bailed_Out};
        return $finalize;
    }
}

=head1 AUTHOR

osfameron <osfameron@cpan.org> 2014

=cut

1;
