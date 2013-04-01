use REST::Client;
use JSON;
use XML::XPath;
use MIME::Base64;
use strict;
 
my $smix_us = "https://smix.prod.us.ccp.rackspace.net";
my $auth_us = "https://identity.api.rackspacecloud.com";
my $ci_svc  = "https://configuration-item.api.rackspacecloud.com";
my $nastId = 0;
my $account=0;

if($#ARGV >= 0) {
    $nastId = $ARGV[0];
}
$account = get_tenants_in_auth_us($nastId); 

#print $account."\n";
printf ",";
get_account($account);
printf ",";
get_tenants_in_ci_service($nastId);
printf "\n";

sub get_client {
    my $host = shift;
    my $client = REST::Client->new();
    $client->setHost($host);
    $client->getUseragent()->ssl_opts(SSL_verify_mode => 0);
    $client->setFollow(1);
	return $client;
}

sub get_account {
    my $account1 = shift;
	
    my $request_body = "<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:ns=\"http://cloud.rackspace.com/account/1.0\">";
    $request_body = $request_body."<soapenv:Header/>";
    $request_body = $request_body."<soapenv:Body><ns:GetAccount><ns:accountId>";
    $request_body = $request_body.$account1;
    $request_body = $request_body."</ns:accountId></ns:GetAccount></soapenv:Body>";
    $request_body = $request_body."</soapenv:Envelope>";
    #print $request_body."\n";
	
    my $client = REST::Client->new();
    $client->setHost($smix_us);
	$client->addHeader("SOAPAction", "http://cloud.rackspace.com/account/service/1.0/GetAccount");

    $client->getUseragent()->ssl_opts(SSL_verify_mode => 0);
	$client->getUseragent()->ssl_opts(verify_hostname => 0);
	
    $client->POST('account/1.0', $request_body);
	printf "%s,", $client->responseCode();
    if($client->responseCode() eq '200') {
	    #print $client->responseContent();
		my $response = $client->responseContent();
		$response = "<?xml version='1.0' encoding='ISO-8859-1' ?>".$response;
        #my $xp = XML::XPath->new(xml => $client->responseContent());
		my $xp = XML::XPath->new(xml => $response);
        $xp->set_namespace("ns1", "http://cloud.rackspace.com/account/1.0");
        my $nodeset = $xp->find("//ns1:accountType");
		
		if($nodeset->size() > 0) {
            foreach my $node ($nodeset->get_nodelist) {
                printf "%s,",$node->string_value();
            }
		} else {
		    printf "%s,",$client->responseContent();
		}	
		$nodeset = $xp->find("//ns1:createdDate");
		if($nodeset->size() > 0) {
            foreach my $node ($nodeset->get_nodelist) {
                printf "%s,",$node->string_value();
            }
		} else {
		    printf "%s,",$client->responseContent();
		}
		$nodeset = $xp->find("//ns1:termsAndConditions");
		if($nodeset->size() > 0) {
            foreach my $node ($nodeset->get_nodelist) {
                printf "%s",$node->string_value();
            }
		} else {
		    printf "%s",$client->responseContent();
		}
    } else {
	    printf "%s,%s,%s",$client->responseContent(),"","";
	}
	
}

sub get_tenants_in_auth_us {
    my $nastId = shift;
	my $client = get_client($auth_us);
    my $auth_header = "Basic ".encode_base64("configitemsvc:3wugwBDDt792guodihEFDH");
    $client->addHeader('Authorization',$auth_header); 
    my $url = "v1.1/nast/".$nastId;
    $client->GET($url);
    if($client->responseCode() eq '200') {
	    #print $client->responseContent();
        my $json_response = $client->responseContent();
        my $perl_scalar = decode_json($json_response);
        printf "%s,%s,%s,%s,%s", $client->responseCode(), $perl_scalar->{"user"}->{"mossoId"}, $perl_scalar->{"user"}->{"nastId"}, $perl_scalar->{"user"}->{"created"}, $perl_scalar->{"user"}->{"updated"} ;
		return $perl_scalar->{"user"}->{"mossoId"};
    } else {
	    printf "%s,%s,%s,%s,%s", $client->responseCode(), "", $nastId, "", "";        
		return 0;
	}

}

sub get_tenants_in_ci_service {
    my $nastId = shift;
	my $client = get_client($ci_svc);
    #my $auth_header = "Basic ".encode_base64("configitemsvc:3wugwBDDt792guodihEFDH");
    $client->addHeader('X-Auth-Token','f26c7746f2174b6590f16f6f58d352a7'); 
    my $url = "v1/ci/tenants?id=".$nastId;
	#print $url;
    $client->GET($url);
	printf "%s,",$client->responseCode();
    if($client->responseCode() eq '200') {
	    #print $client->responseContent();
		my $response = $client->responseContent();
		my $xp = XML::XPath->new(xml => $response);
        $xp->set_namespace("ns1", "http://configuration-item.api.rackspacecloud.com/v1");
		my $nodeset = $xp->find("//ns1:tenant/\@id");
		if($nodeset->size() > 0) {
            printf "%s,", "TENANT_FOUND";
			my $nodeset = $xp->find("//ns1:billing-account/\@id");
		    if($nodeset->size() > 0) {
                foreach my $node ($nodeset->get_nodelist) {
                    printf "%s", $node->string_value();
                }
		    } else {
		        printf "%s", "BILLING_ACCOUNT_NOT_FOUND";
		    }
		} else {
		    printf "%s", "TENANT_NOT_FOUND";
		}
        
    } else {
	    printf "%s", "TENANT_NOT_FOUND";        
		return 0;
	}

}