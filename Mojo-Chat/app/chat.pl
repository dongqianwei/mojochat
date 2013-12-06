use v5.16;
use Mojolicious::Lite;

my %online;
my %online_rec;

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
  	$online_rec{$name} = 5;
  }
  elsif ($name ne $self->session('name')) {
  	#session exists
  	#name changed
  	my $ori_name = $self->session('name');
    $self->session(name => $name);
    $online{$name} = delete $online{$ori_name};
    $online_rec{$name} = delete $online_rec{$ori_name};
  }
  $self->stash(name => $name);
};

get 'serv' => sub {
	my $self = shift;
	my $name = $self->session('name');
	#刷新计数
	$online_rec{$name} = 5;
	#获取在线人数
	my @names = keys %online;
	#将消息队列刷新
    my @msgs = @{$online{$name}{msgq} // []};
    $online{$name}{msgq} = [];
	$self->render(json => {name => "@names", msg => "@msgs"});
};

get '/msg' => sub {
	my $self = shift;
	my $name = $self->session('name');
	my $msg = $self->param('msg') . " from $name\n";
	#将msg添加到所有人的消息队列中
	for my $name (keys %online) {
		push @{$online{$name}{msgq}}, $msg;
	}
	$self->render(json => 'succ');
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
  Mojo::IOLoop->timer(10 => __SUB__);
}

Mojo::IOLoop->timer(10 => \&refresh);

app->start;
