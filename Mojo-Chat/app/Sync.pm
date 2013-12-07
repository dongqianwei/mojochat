package Sync;
use Mojo::Base "Mojo::EventEmitter";

sub trigger {
	my $self = shift;
	$self->emit('sync');
}

1;