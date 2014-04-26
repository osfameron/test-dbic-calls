package Test::DBIC::Calls;
use parent 'Test::Builder::Module';
use Test::DBIC::Profiler;

our @EXPORT = qw( with_stats );

=head1 NAME

Test::DBIC::Calls - test statistics about your DBIC calls

=head1 SYNOPSIS

Run a subtest with a debugging object (L<Test::DBIC::Profiler>) set to capture
the number of calls that have been made to the database. This may be useful to
check your assumptions about prefetching, etc.

    use Test::More;
    use Test::DBIC::Calls;

    # get a DBIC object, for example using Test::DBIx::Class
    use Test::DBIx::Class;
    my $db = Schema;

    with_stats 'test 1', $db, sub {
        my $stats = shift;

        my $rs = $db->resultset('Foo')->search();
        is $stats->call_count, 0, 'No calls on preparing RS';

        my @foo = $rs->all;
        is $stats->call_count, 1, '1 call after preparing RS';
    };

=head1 EXPORTED FUNCTIONS

=over 4

=item C<with_stats $name, $db, $code>

The L<Test::DBIC::Profiler> object is created for the database and is passed to
your code reference as its first and only argument.

=back

=cut

sub with_stats {
    my ($name, $db, $subtest) = @_;

    my $storage = $db->storage;
    my %old = (
        debug    => $storage->debug,
        debugobj => $storage->debugobj,
    );
    my $stats = Test::DBIC::Profiler->new();
    $storage->debug(1);
    $storage->debugobj( $stats );

    subtest_with( "With stats: $name", $subtest, $stats );

    $storage->debug( $old{debug} );
    $storage->debugobj( $old{debugobj} );
}

# I couldn't figure out how to do a subtest wrapper without all this, cargo
# culted from TB->subtest.  Is there a better way?  Or worth contributing this
# back to TB?
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
