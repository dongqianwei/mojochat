package MsgBox;
use Mojo::Base 'Mojo::EventEmitter';

# 向某昵称对应的人发送消息
# 即触发somebody_msg_event事件
sub send_msg {
    my ($self, $rev, $msg) = @_;
    $self->emit($rev.'_msg_event' => $msg);
}

1;