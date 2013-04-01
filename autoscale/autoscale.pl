#! /usr/bin/perl

use strict;
use warnings;

use DBI;
#use DBD::mysql;
use Fcntl qw(:DEFAULT :flock);

my $install_path="/home/midhun/projects/cloud-automation";
my $debug = 0;
my $node_prefix = "wordpress";
my $account_id = $ENV{'RACKSPACE_ACCOUNT_NUMBER'};
my $lb_id = "104017";

sub get_connection {
    # CONFIG VARIABLES
    my $platform = "mysql";
    my $database = "monitoring";
    my $host = "166.78.150.51";
    my $port = "3306";
    my $user = "admin";
    my $pw = "admin";

    # DATA SOURCE NAME
    my $dsn = "dbi:mysql:$database:$host:$port";

    # PERL DBI CONNECT
    my $connect = DBI->connect($dsn, $user, $pw);
    return $connect;
}

sub get_autoscale_action {
    # PREPARE THE QUERY
    my $connect = get_connection();
    my $status;
    my $query = "SELECT status FROM autoscale_actions where id=1";
    my $query_handle = $connect->prepare($query);

    # EXECUTE THE QUERY
    $query_handle->execute();

    # BIND TABLE COLUMNS TO VARIABLES
    $query_handle->bind_columns(undef, \$status);

    # LOOP THROUGH RESULTS
    while($query_handle->fetch()) {
        $debug || print "Received status :  $status\n";
    } 

    $connect->disconnect();

    return $status;
}

sub create_file_lock {
    my $lockfile = '/tmp/autoscalelockfile';
    open(my $fhpid, '>', $lockfile) or die "error: open '$lockfile': $!";
    flock($fhpid, LOCK_EX|LOCK_NB) or die "$0 already running. Exiting\n";
}

sub set_status {

    my $status = shift;
    my $connect = get_connection();
    
    # PREPARE THE QUERY
    my $query = "update autoscale_actions set status='$status' where id=1";
    my $query_handle = $connect->prepare($query);

    # EXECUTE THE QUERY
    $query_handle->execute();

    $connect->disconnect();
}

sub update_node_count {
   my $new_node_count = shift;
    my $status = shift;
    my $connect = get_connection();
    
    # PREPARE THE QUERY
    my $query = "update node_counter set count='$new_node_count' where id=1";
    my $query_handle = $connect->prepare($query);

    # EXECUTE THE QUERY
    $query_handle->execute();

    $connect->disconnect();
}

sub get_current_nodes {
    #Return hash of node names and IP address
    my @nodes;
    my $node_count = 0;
    open(KNIFE, "knife rackspace server list |") || die "Unable to run knife rackspace server list\n";
    while(<KNIFE>) {
        print $_;
        my @node_attribs = split(/[ \t]+/);
        if($node_attribs[1] =~ /wordpress\d/) {
            my $node = {
                "id" => $node_attribs[0],
                "name" => $node_attribs[1],
                "pvt_ip" => $node_attribs[3]
            };
            printf "%s, %s, %s\n", $node->{"id"}, $node->{"name"}, $node->{"pvt_ip"};
            $nodes[$node_count] = $node;
            $node_count++;
        }
        
    }
    return @nodes;
}

sub addto_loadbalancer {
    my $ip = shift;
    $debug || print "Adding node $ip to load blanacer\n"; 
    my $cmd = "perl $install_path/loadbalancer/loadbalancer_addnodes.pl -a $account_id -l 104017 -n $ip -p 80";
    print "Executing $cmd ... \n"; 
    #TODO: Enable load balanced create
    open(ADDLB, "$cmd |") || print "Load balancer add command failed to start ...\n";
    while(<ADDLB>) {
        print $_;
    }
}

sub removefrom_loadbalancer {
    my $ip = shift;
    $debug || print "Removing node $ip to load blanacer\n"; 
    my $cmd = "perl $install_path/loadbalancer/loadbalancer_removenodes.pl -a $account_id -l 104017 -n $ip";
    print "Executing $cmd ... \n"; 
    #TODO: Enable load balancer delete
    open(REMOVELB, "$cmd |") || print "Load balancer add command failed to start ...\n";
    while(<REMOVELB>) {
        print $_;
    }
}


sub create_node {
    $debug || print "Getting current node list ....\n";
    my @nodes = get_current_nodes();
    my $node_count = $#nodes + 1;
    $debug || print "Number of nodes found = $node_count\n"; 
    #$debug || print "Node 0 is ".$nodes[0]->{"name"}."\n";

    if($node_count < 2) {
        printf "Node count received is less that 2 ... exiting\n";
        exit();
    }

    my $new_node = $node_prefix.($node_count + 1);
    print "New node name = $new_node\n";

    # Run create node command
    my $cmd = "knife rackspace server create -r 'role[wordpress-nodb]' --server-name $new_node --node-name $new_node --image 7480d067-b60b-424c-bf8b-1a5ea14b4024 --flavor 2 > $install_path/$new_node.out";
    print "Executing $cmd ....\n";
    # TODO: Enable create command
    open(ADDNODE, "$cmd |") || print "Failed to run $cmd";
    while(<ADDNODE>) {
        print $_;
    }

    print "Add node complete ....\n";
    print "Getting list of current nodes ...\n";
    @nodes = get_current_nodes();
    #TODO: Remove testing code
    #print "Testing with wordpress3\n";
    #$new_node="wordpress3";
    my $new_node_ip;
    for(my $i = 0; $i <= $#nodes; $i++) {
        if($nodes[$i]->{"name"} eq $new_node) {
            $new_node_ip = $nodes[$i]->{"pvt_ip"};
            last;
        }
    }
    $debug || print "New node private ip = $new_node_ip\n";
    addto_loadbalancer($new_node_ip);
    update_node_count($node_count + 1);
}

sub delete_node {
    $debug || print "Getting current node list ....\n";
    my @nodes = get_current_nodes();
    my $node_count = $#nodes + 1;
    $debug || print "Number of nodes found = $node_count\n"; 

    my $delete_node = $node_prefix.($node_count);
    print "Node to be deleted = $delete_node\n";

    my $delete_node_ip;
    my $delete_node_id;
    for(my $i = 0; $i <= $#nodes; $i++) {
        if($nodes[$i]->{"name"} eq $delete_node) {
            $delete_node_ip = $nodes[$i]->{"pvt_ip"};
            $delete_node_id = $nodes[$i]->{"id"};
            last;
        }
    }
    $debug || print "Delete node ip = $delete_node_ip\n";
    removefrom_loadbalancer($delete_node_ip);


    sleep(30);

    # Delete server
    my $cmd = "knife rackspace server delete $delete_node_id -y -P";
    print "Executing $cmd ....\n";
    # TODO: Enable delete command
    open(DELETENODE, "$cmd |") || print "Failed to run $cmd";
    while(<DELETENODE>) {
        print $_;
    }
    update_node_count($node_count - 1);
}

# Create file lock
print "Running autoscale.pl at ".(localtime)."\n";
create_file_lock();
$debug || print "Created file lock\n";

my $action = get_autoscale_action();
$debug || print "Fetched autoscale actions\n";

if($action eq 'CREATE') {
    $debug || print "Action required is CREATE\n";
    set_status("IN_PROGRESS");
    $debug || print "Status updated to IN_PROGRESS\n";
    create_node();
    $debug || print "New node created\n";
    set_status("COMPLETE");
    $debug || print "Status updated to COMPLETE\n";
} 

if($action eq 'DELETE') {
    $debug || print "Action required is DELETE\n";
    set_status("IN_PROGRESS");
    $debug || print "Status updated to IN_PROGRESS\n";
    delete_node();
    $debug || print "Node deleted\n";
    set_status("COMPLETE");
    $debug || print "Status updated to COMPLETE\n";
}


# if "Delete" run the knife rackspace server delete command" as wordpress[n]
# Remove node from the load balancer
# Wait 60 seconds

# Do graceful shutdown of apache server
#knife ssh name:wordpress3 -a ipaddress -u username -x root -P password ls


# Sleep another X seconds for stabilization if no rule exists

# Remove file lock

#Cleanup old metrics
#delete from node_metrics where time_stamp < DATE_SUB(now(), INTERVAL 30 MINUTE);
