package MsgBox;
use Mojo::Base 'Mojo::EventEmitter';
use Mojo::IOLoop;

sub register {
    my ($self, $recv, $cb) = @_;
    my $cb_once = $self->once($recv.'_msg_event' => $cb);
    
    #10s 自动超时
    Mojo::IOLoop->timer(10 => sub {
        #如果回调函数还存在就触发
        say for @{$self->subscribers($recv.'_msg_event')};
        if ( grep {$_ eq $cb_once} @{$self->subscribers($recv.'_msg_event')} ) {
            say 'msgbox callback timout, so called';
            $cb_once->('');
        }
    });
}

# 向某昵称对应的人发送消息
# 即触发somebody_msg_event事件
sub send_msg {
    my ($self, $to, $msg) = @_;
    $self->emit($to.'_msg_event' => $msg);
}

sub broadcast {
    my $self = shift;
    $self->emit('sync');
}

1;