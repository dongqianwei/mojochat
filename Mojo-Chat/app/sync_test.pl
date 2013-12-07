use v5.18;
use Mojolicious;
use Sync;

my $sync = Sync->new;
$sync->on(sync =>sub {say 'triggered he'});
$sync->on(sync =>sub {say 'triggered she'; Mojo::IOLoop->stop});

$sync->trigger;

Mojo::IOLoop->start;
say 'the end';
<>;