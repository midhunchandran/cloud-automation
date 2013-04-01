#! /usr/bin/perl
use REST::Client;
use JSON;
use strict;

my $rack_identity_url = "https://identity.api.rackspacecloud.com/v2.0";
my $rack_loadbalancer_url = "https://dfw.loadbalancers.api.rackspacecloud.com/v1.0";
my $rack_user = $ENV{'RACKSPACE_API_USERNAME'};
my $rack_apikey = $ENV{'RACKSPACE_API_KEY'};
my $rack_accountId = "";
my $lb_id = "";
my $node_ip = "";
my $node_port = "";
my $auth_token = "";
use vars qw/ %opt /;


sub init()
{
    use Getopt::Std;
    my $opt_string = 'a:l:n:p:';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if !defined $opt{a};
    usage() if !defined $opt{l};
    usage() if !defined $opt{n};
    usage() if !defined $opt{p};
    $rack_accountId = $opt{a};
    $lb_id = $opt{l};
    $node_ip = $opt{n};
    $node_port = $opt{p};
}

sub usage()
{
    print STDERR << "EOF";
This program does...

usage: $0 -a accountId -l load_balancer_id -n node_ip_address -p port

  -a        : Rackspace account number
  -l        : Loadbalancer id
  -n        : IP address of the loadbalanced node
  -p        : Port on the loadbalanced node

  example: $0 -a 34536 -l 2342 -n 10.181.5.67 -p 80

EOF
    exit;
}

sub get_client {
    my $host = shift;
    my $client = REST::Client->new();
    $client->setHost($host);
    $client->getUseragent()->ssl_opts(SSL_verify_mode => 0);
    $client->setFollow(1);
    return $client;
}

sub authenticate {
    my $req_body = "{ \"auth\": { \"RAX-KSKEY:apiKeyCredentials\": { \"username\": \"$rack_user\", \"apiKey\" : \"$rack_apikey\"} } }";
    #printf "%s\n", $req_body;
    my $client = get_client($rack_identity_url);
    $client->addHeader('Content-Type', 'application/json');
    $client->POST('tokens', $req_body);
    if($client->responseCode() eq '200') {
        my $resp = $client->responseContent();
        my $resp_parsed = decode_json($resp);
        $auth_token = $resp_parsed->{"access"}->{"token"}->{"id"}; 
        #printf "Token: %s\n", $auth_token;
    } else {
        printf "Request failed with response %s %s", $client->responseCode(), $client->responseContent();
    }
}

sub add_nodes {
    my $req_body = "{ \"nodes\": [";
    $req_body = $req_body."{ \"address\": \"$node_ip\", \"port\": $node_port, \"condition\": \"ENABLED\" }"; 
    $req_body = $req_body."] }"; 
    #printf "%s", $req_body;
    my $client = get_client($rack_loadbalancer_url);
    $client->addHeader('Content-Type', 'application/json');
    $client->addHeader('X-Auth-Token', $auth_token);
    $client->POST("$rack_accountId/loadbalancers/$lb_id/nodes", $req_body);
    if($client->responseCode() eq '200' || $client->responseCode() eq '202') {
        my $resp = $client->responseContent();
        my $resp_parsed = decode_json($resp);
        printf "Successfully added node to Load Balancer : %s\n", $lb_id;
    } else {
        printf "Request failed with response %s %s", $client->responseCode(), $client->responseContent();
    }
}

init();
authenticate();
add_nodes();
#curl -i -d '{ "auth": { "RAX-KSKEY:apiKeyCredentials": { "username": "your_username", "apiKey": "your_api_key"} } }' -H 'Content-Type: application/json' 'https://identity.api.rackspacecloud.com/v2.0/tokens'
#curl -i -d '{ "loadBalancer": { "name": "a-new-loadbalancer", "port": 80, "protocol": "HTTP", "virtualIps": [ { "type": "PUBLIC" } ], "nodes": [ { "address": "<IP address of FIRST cloud server>", "port": 80, "condition": "ENABLED" } ] } }' -H 'X-Auth-Token: your_auth_token' -H 'Content-Type: application/json' 'https://dfw.loadbalancers.api.rackspacecloud.com/v1.0/your_acct_id/loadbalancers'
