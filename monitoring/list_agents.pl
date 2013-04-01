#! /usr/bin/perl
use REST::Client;
use JSON;
use strict;

use vars qw/ %opt /;
my $rack_identity_url = "https://identity.api.rackspacecloud.com/v2.0";
my $rack_database_url = "https://monitoring.api.rackspacecloud.com/v1.0";
my $rack_user = $ENV{'RACKSPACE_API_USERNAME'};
my $rack_apikey = $ENV{'RACKSPACE_API_KEY'};
my $rack_accountId = "";
my $node_ip = "";
my $node_port = "";
my $auth_token = "";
my $db_hostname = "";

sub init()
{
    use Getopt::Std;
    my $opt_string = 'a:';
    getopts( "$opt_string", \%opt ) or usage();
    usage() if !defined $opt{a};
    $rack_accountId = $opt{a};
}

sub usage()
{
    print STDERR << "EOF";
This program does...

usage: $0 -a accountId 

  -a        : Rackspace account number

  example: $0 -a 34536 

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
    my @databases;
    my $flavorRef = "$rack_database_url/$rack_accountId/flavors/1";
    my $name = "dbinstance";
    my @users;
    my $volume = {};

    $databases[0]->{"character_set"} = "utf8";
    $databases[0]->{"collate"} = "utf8_general_ci";
    $databases[0]->{"name"} = "wordpressdb";

    $users[0]->{"databases"}[0]->{"name"} = "wordpressdb";
    $users[0]->{"name"} = "wordpressuser";
    $users[0]->{"password"} = "passw0rd";

    $volume->{"size"} = 2;

    my $request = {};
    $request->{"instance"}->{"databases"} = \@databases;
    $request->{"instance"}->{"flavorRef"} = $flavorRef;
    $request->{"instance"}->{"name"} = $name;
    $request->{"instance"}->{"users"} = \@users;
    $request->{"instance"}->{"volume"} = $volume;

    return $request;

}

sub list_entities {
    my $req_scalar = create_request();
    my $req_json = encode_json($req_scalar);
    #print $req_json."\n";
    #printf "%s", $req_body;
    my $client = get_client($rack_database_url);
    $client->addHeader('Content-Type', 'application/json');
    $client->addHeader('X-Auth-Token', $auth_token);
    $client->GET("$rack_accountId/agents");
    if($client->responseCode() eq '200' || $client->responseCode() eq '202') {
        my $resp = $client->responseContent();
        my $resp_parsed = decode_json($resp);
        printf "Entities: %s \n", $resp;
        
        return 0;
    } else {
        printf "Create Request failed with response %s %s", $client->responseCode(), $client->responseContent();
        return 1;
    }
}


init();
authenticate();
list_entities();

#curl -i -d '{ "auth": { "RAX-KSKEY:apiKeyCredentials": { "username": "your_username", "apiKey": "your_api_key"} } }' -H 'Content-Type: application/json' 'https://identity.api.rackspacecloud.com/v2.0/tokens'
#curl -i -d '{ "loadBalancer": { "name": "a-new-loadbalancer", "port": 80, "protocol": "HTTP", "virtualIps": [ { "type": "PUBLIC" } ], "nodes": [ { "address": "<IP address of FIRST cloud server>", "port": 80, "condition": "ENABLED" } ] } }' -H 'X-Auth-Token: your_auth_token' -H 'Content-Type: application/json' 'https://dfw.loadbalancers.api.rackspacecloud.com/v1.0/your_acct_id/loadbalancers'
