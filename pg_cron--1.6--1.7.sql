/* pg_cron--1.6--1.7.sql */

ALTER TABLE cron.job ADD COLUMN scope text NOT NULL DEFAULT 'primary' CHECK (scope IN ('primary', 'standby', 'both'));

CREATE FUNCTION cron.schedule(job_name text,
                              schedule text,
                              command text,
                              scope text)
RETURNS bigint
LANGUAGE C
AS 'MODULE_PATHNAME', $$cron_schedule_named$$;
COMMENT ON FUNCTION cron.schedule(text,text,text,text)
IS 'schedule a pg_cron job with a name and scope';

CREATE FUNCTION cron.alter_job(job_id bigint,
								schedule text,
								command text,
								database text,
								username text,
								active boolean,
								scope text)
RETURNS void
LANGUAGE C
AS 'MODULE_PATHNAME', $$cron_alter_job$$;

COMMENT ON FUNCTION cron.alter_job(bigint,text,text,text,text,boolean,text)
IS 'Alter the job identified by job_id. Any option left as NULL will not be modified.';

CREATE FUNCTION cron.schedule_in_database(job_name text,
										  schedule text,
										  command text,
										  database text,
										  username text,
										  active boolean,
										  scope text)
RETURNS bigint
LANGUAGE C
AS 'MODULE_PATHNAME', $$cron_schedule_named$$;

COMMENT ON FUNCTION cron.schedule_in_database(text,text,text,text,text,boolean,text)
IS 'schedule a pg_cron job in a database with a scope';

/* admin should decide whether cron.schedule_in_database is safe by explicitly granting execute */
REVOKE ALL ON FUNCTION cron.schedule_in_database(text,text,text,text,text,boolean,text) FROM public;
