package snapdance;
use Dancer2;

our $VERSION = '0.1';

my $SNAPCAST = SnapcastQueries->new( config => config()->{'snapcast'} );

my @DEFAULT_COLORS = map { "#$_"} qw{0C0 C00 00C e5c837};

get '/' => sub {

# refresh the client on each homepage (do not cache if another browser is also updating it)

    my $clients = $SNAPCAST->get_clients();

    my $cfg = config()->{'snapcast'};
    die "no snapcast configuration set" unless $cfg;
    use Data::Dumper;

    #print Dumper config()->{'snapcast'};
    my $cfgrooms = $cfg->{rooms} or die;
    foreach my $room ( keys %$cfgrooms ) {
        my $lc = lc $room;
        next if $lc eq $room;
        $cfgrooms->{$lc} = $cfgrooms->{$room};
    }

    my @rooms;
    my $roomnumber = 1;
    my $id = 1;
    
    foreach my $cli (@$clients) {
        my $clientid = lc $cli->{clientid};

        # ignore the client
        next if grep { lc($_) eq $clientid } @{ $cfg->{ignore} // [] };
        push @rooms,
          {
            id       => 'room' . $roomnumber++,
            name     => $cfgrooms->{$clientid}->{name} // "Client from $clientid",
            clientid => $clientid,
            color    => $cfgrooms->{$clientid}->{color} // $DEFAULT_COLORS[ ( $roomnumber - 2 ) % ( $#DEFAULT_COLORS + 1 ) ],
            value    => $cli->{volume},
            muteval  => $cli->{muted},

          };
    }
    @rooms = sort { lc( $a->{name} ) cmp lc( $b->{name} ) } @rooms;
    template 'index', { rooms => \@rooms };
};

get '/api/setsound/:room/:muted/:percent' => sub {
    header 'Content-Type' => 'application/json';

    my $room   = param('room');
    my $percent = param('percent');
    my $muted = param('muted');
    

    my $error;
    $error = "Invalid volume" if $percent !~ qr{^[0-9]+$} or $percent > 100;

    my $reply;
    my $reply1;

    if ( !$error ) {
        $reply = $SNAPCAST->set_volume( $room,  $muted, $percent);

        $error = "Volume queries failed" unless exists $reply->{'result'}{'volume'}{'percent'} && $reply->{'result'}{'volume'}{'percent'} == $percent;
    }

    return to_json { status => 0, msg => $error } if $error;
    return to_json { status => 1, msg => "OK: $room - :$muted:- :$percent: ",
        debug => $reply };
};

#.... move this to a library
{

    package SnapcastQueries;

    use JSON::XS;
    #use JSON;
    use Net::Telnet;
    use Data::Dumper;
    use Simple::Accessor qw{config hostname port};
    use strict;
 #   use constant { #real true false, compatible with encode_json decode_json for later (we don't want field:false... will be field:0...)
 #               eTRUE  =>  bless( do{\(my $o = 1)}, 'JSON::PP::Boolean' ),
 #               eFALSE =>  bless( do{\(my $o = 0)}, 'JSON::PP::Boolean' )
 #            };



    sub _build_hostname {
        my $cfg = $_[0]->config();
        my $h = eval { $cfg->{server}{host} }
          or die "No server host defined in configuration";

        return $h;
    }

    sub _build_port {
        my $cfg = $_[0]->config();
        return $cfg->{server}{port} // 1705;
    }

    sub is_demo {
        my $cfg = $_[0]->config();
        return $cfg->{demo} ? 1 : 0;
    }

    sub do_request {
        my ( $self, $query ) = @_;

        if (  $self->is_demo() ) {
            my $fake = {};
            require File::Slurp;
            if ( $query->{'method'} eq 'Server.GetStatus' ) {
                my $content = File::Slurp::slurp("./t/fixtures/server_status.json") or die $!;
                $fake = JSON::XS->new->utf8->decode($content);
                # add some extra clients
                push @{$fake->{result}{clients}}, @{$fake->{result}{clients}} for 1..1;
            }
            return $fake;
        }

        my $snapserver = $self->hostname();
        my $port       = $self->port();

        $self->{_request_id} ||= 1;
        my $json = JSON::XS->new->utf8->encode(
            { %$query, id => $self->{_request_id} } );

        $self->{_request_id} = ( $self->{_request_id} + 1 ) % 65_536;

        my $t = Net::Telnet->new( Timeout => 10, Prompt => "/\n/" );
        $t->open( Host => $snapserver, Port => $port ) or die;
        
        #String conversion for Mute
        $json =~ s/"muted":"true"/"muted":true/ig;
        $json =~ s/"muted":"false"/"muted":false/ig;
        $json =~ s/"muted":"0"/"muted":false/ig;
        $json =~ s/"muted":"1"/"muted":true/ig;

        print Dumper $json;

        my ($reply) = $t->cmd( $json . "\r\n" );
        $t->close;

        my $results = JSON::XS->new->utf8->decode($reply);

        die "Cannot connect to snapserver" unless ref $results;

        return $results;
    }

    sub get_clients {
        my $self = shift;

        my $results = $self->do_request(
            { 'jsonrpc' => '2.0', 'method' => 'Server.GetStatus' } );
            
            


        die "No clients connected to server"
          unless ref $results->{result}{server}{groups}
          && scalar @{ $results->{result}{server}{groups} };

        my @clients;
        foreach my $group ( @{ $results->{result}{server}{groups} } ) {
            foreach my $client ( @{ $group->{clients} } ) {
                next if !$client->{connected}; # Ignore disconnected clients
                push @clients,
                  {
                    clientid => $client->{'id'},            
                    muted    => $client->{'config'}{'volume'}{'muted'},
                    volume   => $client->{'config'}{'volume'}{'percent'},
                  };
            }
        }

        @clients = sort { $a->{clientid} cmp $b->{clientid} } @clients;

        return \@clients;
    }

    sub set_volume {

        
        my ( $self, $clientid, $muted, $volume ) = @_;
        my $results = $self->do_request(
            {
                
                'jsonrpc' => '2.0',
                'method'  => 'Client.SetVolume',
                'params'  => { 'id' => $clientid, 'volume' => { 'muted' => $muted, 'percent' => int($volume) } },


                'id' => 1 # request id
            }
        );

        #print Dumper $results;
        return $results;
    }
}

true;
