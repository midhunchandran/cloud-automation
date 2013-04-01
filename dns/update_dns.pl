#! /usr/bin/perl
use REST::Client;
use JSON;
use strict;

use vars qw/ %opt /;
my $rack_identity_url = "https://identity.api.rackspacecloud.com/v2.0";
my $rack_database_url = "https://dns.api.rackspacecloud.com/v1.0";
my $rack_user = $ENV{'RACKSPACE_API_USERNAME'};
my $rack_apikey = $ENV{'RACKSPACE_API_KEY'};
my $rack_accountId = "";
my $ip = "";
my $node_port = "";
my $auth_token = "";

sub init()
{
    use Getopt::Std;
    my $opt_string = 'a:n:p:';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if !defined $opt{a};
    usage() if !defined $opt{p};
    $rack_accountId = $opt{a};
    $ip = $opt{p};
}

sub usage()
{
    print STDERR << "EOF";
This program does...

usage: $0 -a accountId -p node_ip_address

  -a        : Rackspace account number
  -p        : Domain IP address

  example: $0 -a 34536 -p 10.181.5.67

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
        printf "Auth Request failed with response %s %s", $client->responseCode(), $client->responseContent();
    }
}

sub create_request {
    my $request = {};
    $request->{"name"} = "demo.cloudmovers.org";
    $request->{"type"} = "A";
    $request->{"data"} = $ip;

    return $request;

}

sub update_dns_record {
    my $req_scalar = create_request();
    my $req_json = encode_json($req_scalar);
    #print $req_json."\n";
    #printf "%s", $req_body;
    my $client = get_client($rack_database_url);
    $client->addHeader('Content-Type', 'application/json');
    $client->addHeader('X-Auth-Token', $auth_token);
    $client->PUT("$rack_accountId/domains/3606324/records/A-9610953", $req_json);
    if($client->responseCode() eq '200' || $client->responseCode() eq '202') {
        my $resp = $client->responseContent();
        my $resp_parsed = decode_json($resp);
        printf "Updated DNS record  \n", $client->responseContent();
    } else {
        printf "DNS Update Request failed with response %s %s", $client->responseCode(), $client->responseContent();
    }
}

init();
authenticate();
update_dns_record();
#curl -i -d '{ "auth": { "RAX-KSKEY:apiKeyCredentials": { "username": "your_username", "apiKey": "your_api_key"} } }' -H 'Content-Type: application/json' 'https://identity.api.rackspacecloud.com/v2.0/tokens'
#curl -i -d '{ "loadBalancer": { "name": "a-new-loadbalancer", "port": 80, "protocol": "HTTP", "virtualIps": [ { "type": "PUBLIC" } ], "nodes": [ { "address": "<IP address of FIRST cloud server>", "port": 80, "condition": "ENABLED" } ] } }' -H 'X-Auth-Token: your_auth_token' -H 'Content-Type: application/json' 'https://dfw.loadbalancers.api.rackspacecloud.com/v1.0/your_acct_id/loadbalancers'
