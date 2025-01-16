# Test that jobs running on the primary report job run details
# and that tests running on the standby run but do not report the details.

use strict;
use warnings FATAL => 'all';
use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;
use Test::More;


# set up pg_cron on the primary
my $node_primary = PostgreSQL::Test::Cluster->new('primary');
$node_primary->init(allows_streaming => 1);

$node_primary->append_conf(
	'postgresql.conf', qq[
shared_preload_libraries = 'pg_cron'
cron.use_background_workers = 'on'
]);
$node_primary->start;

$node_primary->safe_psql('postgres',
	qq[CREATE EXTENSION pg_cron]);


# create jobs on the primary
$node_primary->safe_psql('postgres',
	q[
SELECT cron.schedule('run-on-primary-only', '1 seconds',
	'SELECT ''run-on-primary-only''', scope := 'primary');
SELECT cron.schedule('run-on-standby-only', '1 seconds',
	'SELECT ''run-on-standby-only''', scope := 'standby');
SELECT cron.schedule('run-on-both', '1 seconds',
	'SELECT ''run-on-both''', scope := 'both');
	]);


# set up the standby
my $backup_name = 'my_backup';
$node_primary->backup($backup_name);

my $node_standby = PostgreSQL::Test::Cluster->new('standby');
$node_standby->init_from_backup($node_primary, $backup_name,
	has_streaming => 1);

$node_standby->start;

# wait for jobs to start and finish
sleep 2;

# check jobs that ran on the primary
ok( $node_primary->log_contains(
		        "cron job .* starting: SELECT 'run-on-primary-only'"),
			    'check that the job run-on-primary-only started on the primary');
ok( !$node_primary->log_contains(
		        "cron job .* starting: SELECT 'run-on-standby-only'"),
			    'check that the job run-on-standby-only did NOT run on the primary');
ok( $node_primary->log_contains(
		        "cron job .* starting: SELECT 'run-on-both'"),
			    'check that the job run-on-both started on the primary');
ok( $node_primary->log_contains(
		        "cron job .* COMMAND completed: SELECT 1 1"),
			    'check that the jobs finished successfully on the primary');

#check jobs that ran on the standby
ok( !$node_standby->log_contains(
		        "cron job .* starting: SELECT 'run-on-primary-only'"),
			    'check that the job run-on-primary-only did NOT run on the standby');
ok( $node_standby->log_contains(
		        "cron job .* starting: SELECT 'run-on-standby-only'"),
			    'check that the job run-on-standby-only started on the standby');
ok( $node_standby->log_contains(
		        "cron job .* starting: SELECT 'run-on-both'"),
			    'check that the job run-on-both started on the standby');
ok( $node_standby->log_contains(
		        "cron job .* COMMAND completed: SELECT 1 1"),
			    'check that the jobs finished successfully on the standby');

# end test
$node_primary->stop;
$node_standby->stop;

done_testing();
