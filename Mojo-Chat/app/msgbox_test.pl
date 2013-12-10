use v5.16;
use MsgBox;
$|++;

my $box = MsgBox->new;

$box->on(tom_msg_event => sub {
    my ($self, $msg) = @_;
    say "tom get an msg: $msg";
});

$box->on(lili_msg_event => sub {
    my ($self, $msg) = @_;
    say "lili get an msg: $msg";
});

$box->send_msg('tom', 'hello');

$box->send_msg('lili', 'hello');