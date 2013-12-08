use v5.16;
use Mojolicious::Lite;
use Sync;

my %online;
my %online_rec;
my $sync = Sync->new;

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
  if (not $self->session('name')) {
  	$self->session(name => $name);
  	#first time login
  	#init msg queue
  	$online{$name} = {msgq => []};
  	#init 计数
  	$online_rec{$name} = 6;
    #触发同步事件
    $sync->trigger;
  }
  elsif ($name ne $self->session('name')) {
  	#session exists
  	#name changed
  	my $ori_name = $self->session('name');
    $self->session(name => $name);
    $online{$name} = delete $online{$ori_name};
    $online_rec{$name} = delete $online_rec{$ori_name};
    #触发同步事件
    $sync->trigger;
  }
  $self->stash(name => $name);
};

get 'serv' => sub {
	my $self = shift;
	my $name = $self->session('name');
	#刷新计数
	$online_rec{$name} = 6;

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
        my $id; $id = $sync->once(sync => sub {
            app->log->debug("an callback called");
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

get '/msg' => sub {
	my $self = shift;
	my $name = $self->session('name');
	my $msg = $self->param('msg') . " from $name\n";
	#将msg添加到所有人的消息队列中
	for my $name (keys %online) {
		push @{$online{$name}{msgq}}, $msg;
	}
    #触发同步事件
    $sync->trigger;
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

post '/cmd' => sub {
	my $self = shift;
	my $cmd = $self->param('cmd');
	if ($cmd eq 'quit') {
		my $name = $self->session('name');
		#clear session and user data
		$self->session(expires => 1);
  		delete $online_rec{$name};
  		delete $online{$name};
  		$self->render(json => 'succ');
	}
};

# 定时减计数
sub refresh {
  for my $name (keys %online_rec) {
  	$online_rec{$name} --;
  	if ($online_rec{$name} == 0) {
  		delete $online_rec{$name};
  		delete $online{$name};
  	}
  }
}

#十秒钟减一次计数
Mojo::IOLoop->recurring(10 => \&refresh);

#每10触发一次同步事件
Mojo::IOLoop->recurring(10 => sub {app->log->debug('sync once');$sync->trigger});

app->start;
