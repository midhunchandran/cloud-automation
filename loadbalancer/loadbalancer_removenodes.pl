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
    $rack_accountId = $opt{a};
    $lb_id = $opt{l};
    $node_ip = $opt{n};
}

sub usage()
{
    print STDERR << "EOF";
This program does...

usage: $0 -a accountId -l load_balancer_id -n node_ip_address 

  -a        : Rackspace account number
  -l        : Loadbalancer id
  -n        : IP address of the loadbalanced node

  example: $0 -a 34536 -l 2342 -n 10.181.5.67 

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

sub delete_nodes {
    my $client = get_client($rack_loadbalancer_url);
    my $node_id;
    $client->addHeader('Content-Type', 'application/json');
    $client->addHeader('X-Auth-Token', $auth_token);
    $client->GET("$rack_accountId/loadbalancers/$lb_id/nodes");
    if($client->responseCode() eq '200' || $client->responseCode() eq '202') {
        my $resp_json = $client->responseContent();
        my $resp = decode_json($resp_json);
        printf "Got current list of nodes from Load Balancer\n", $lb_id;
        for(my $i=0; undef != $resp->{"nodes"}[$i]; $i++) {
            printf "%s, %s\n", $resp->{"nodes"}[$i]->{"id"}, $resp->{"nodes"}[$i]->{"address"};
            if($resp->{"nodes"}[$i]->{"address"} eq $node_ip) {
               $node_id = $resp->{"nodes"}[$i]->{"id"};
               printf "Found matching node_id : %s\n", $node_id;
               last;
            }
        }
    } else {
        printf "Request failed with response %s %s", $client->responseCode(), $client->responseContent();
    }
    if(undef == $node_id) {
        printf "No matching node found \n";
        return;
    }
    printf "Deleting node_id : %s\n", $node_id;
    $client->DELETE("$rack_accountId/loadbalancers/$lb_id/nodes/$node_id");
    if($client->responseCode() eq '200' || $client->responseCode() eq '202') {
        printf "Deleted node %s\n", $node_id;
    } else {
        printf "Request failed with response %s %s", $client->responseCode(), $client->responseContent();
    }
}

init();
authenticate();
delete_nodes();
#curl -i -d '{ "auth": { "RAX-KSKEY:apiKeyCredentials": { "username": "your_username", "apiKey": "your_api_key"} } }' -H 'Content-Type: application/json' 'https://identity.api.rackspacecloud.com/v2.0/tokens'
#curl -i -d '{ "loadBalancer": { "name": "a-new-loadbalancer", "port": 80, "protocol": "HTTP", "virtualIps": [ { "type": "PUBLIC" } ], "nodes": [ { "address": "<IP address of FIRST cloud server>", "port": 80, "condition": "ENABLED" } ] } }' -H 'X-Auth-Token: your_auth_token' -H 'Content-Type: application/json' 'https://dfw.loadbalancers.api.rackspacecloud.com/v1.0/your_acct_id/loadbalancers'
