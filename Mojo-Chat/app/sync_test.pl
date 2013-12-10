use v5.18;
use Sync;
$|++;

my $sync = Sync->new;
$sync->once(sync =>sub {say 'triggered he once'});
$sync->on(sync =>sub {say 'triggered she'});

$sync->trigger;

$sync->trigger;