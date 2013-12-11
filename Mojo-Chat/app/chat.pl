use v5.16;
use Mojolicious::Lite;
use Sync;
use MsgBox;

my %online;
my $msgbox = MsgBox->new;

get '/' => sub {
  my $self = shift;
  if (defined $self->session('name')) {
  	my $name = $self->session('name');
  	$self->redirect_to('/chat?name=' . $name);
  }
} => 'login';

get '/chat' => sub {
  my $self = shift;
  my $name = $self->param('name');

  # first login
  if (not $self->session('name')) {
    app->log->debug("first login, name is $name");
  	$self->session(name => $name);
  	#first time login
  	#init msg queue
  	$online{$name} = {msgq => []};
  	#init 计数
  	$online{$name}{count} = 6;
    #触发同步事件
    $msgbox->broadcast;
  }
  elsif ($name ne $self->session('name')) {
    app->log->debug("login with different name");
  	#session exists
  	#name changed
  	my $ori_name = $self->session('name');
    $self->session(name => $name);
    $online{$name} = delete $online{$ori_name};
    #触发同步事件
    $msgbox->broadcast;
  }
  $self->stash(name => $name);
};

get 'serv' => sub {
	my $self = shift;
	my $name = $self->session('name');
	#刷新计数
	$online{$name}{count} = 6;

    # sync
    if ($self->param('sync')) {
        #获取在线人数
        my @names = keys %online;
        #将消息队列刷新
        my @msgs = @{$online{$name}{msgq} // []};
        $online{$name}{msgq} = [];
        eval {
            $self->render(json => {name => "@names", msg => "@msgs"});
        }
    }
    # async
    else {
        $self->render_later;

        #注册事件，执行一次后销毁
        my $id; $id = $msgbox->once(sync => sub {
            my $name = $self->session('name');
            return unless defined $online{$name};
            app->log->debug("an callback called. name is $name");
            #获取在线人数
            my @names = keys %online;
            #将消息队列刷新
            my @msgs = @{$online{$name}{msgq} // []};
            $online{$name}{msgq} = [];
            eval {
                $self->render(json => {name => "@names", msg => "@msgs"});
            }
        });
    }
};

# 注册信箱回调
get '/msgbox' => sub {
    my $self = shift;
    my $name = $self->session('name');
    $self->render_later;

    app->log->debug("msgbox add an callback on event: " . $name.'_msg_event');

    $msgbox->register($name, sub {
        my ($box, $msg) = @_;
        app->log->debug("${name}'s msgbox get a msg: $msg");
	eval {
	  $self->render(json => {msg => $msg});
	}
    });
};

# 发送私信
get '/msg' => sub {
    my $self = shift;
    my $name = $self->session('name');
    my ($to, $msg) = $self->param(['to', 'msg']);
    app->log->debug("$name send $msg to $to");
    $msgbox->send_msg($to, "$name:$msg");
    $self->render(json => 'succ');
};

# 发送广播消息
get '/broadcast_msg' => sub {
	my $self = shift;
	my $name = $self->session('name');
	my $msg = $self->param('msg') . ":$name";
	#将msg添加到所有人的消息队列中
	for my $name (keys %online) {
		push @{$online{$name}{msgq}}, $msg;
	}
    #触发同步事件
    $msgbox->broadcast;
    $self->render(json => 'succ');
};

get 'query' => sub {
    my $self = shift;
    my $query = $self->param('query');
    my $value = $self->param('value');
    if ($query eq 'name') {
    	my $name_exist = exists $online{$value};
    	$self->render(json => {exists => $name_exist});
    }
};

# change status on server
post '/cmd' => sub {
	my $self = shift;
	my $cmd = $self->param('cmd');
	if ($cmd eq 'quit') {
		my $name = $self->session('name');
		#clear session and user data
		$self->session(expires => 1);
  		delete $online{$name};
  		$self->render(json => 'succ');
	}
};

# 定时减计数
sub refresh {
  for my $name (keys %online) {
  	$online{$name}{count} --;
  	if ($online{$name}{count} == 0) {
  		delete $online{$name};
        $msgbox->broadcast;
  	}
  }
}

#每10s减一次计数
Mojo::IOLoop->recurring(10 => \&refresh);

#每10s触发一次同步广播事件
Mojo::IOLoop->recurring(10 => sub {app->log->debug('sync once');$msgbox->broadcast});

app->start;
