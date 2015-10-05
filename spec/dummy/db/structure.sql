--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

--
-- Name: refresh_materialized_view_dependencies(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION refresh_materialized_view_dependencies() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
        DECLARE
          materialized_dependencies_exists BOOLEAN := (SELECT TRUE FROM pg_class WHERE pg_class.relname = 'materialized_view_dependencies' AND pg_class.relkind = 'm');
          all_dependencies_exists BOOLEAN := (SELECT TRUE FROM pg_class WHERE pg_class.relname = 'all_view_dependencies' AND pg_class.relkind = 'm');
        BEGIN
          RAISE NOTICE 'refreshing view dependency hierarchy';
          IF materialized_dependencies_exists THEN
            REFRESH MATERIALIZED VIEW materialized_view_dependencies;
          END IF;
          IF all_dependencies_exists THEN
            REFRESH MATERIALIZED VIEW all_view_dependencies;
          END IF;
        END
      $$;


--
-- Name: replace_view(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION replace_view(view_name text, new_sql text) RETURNS void
    LANGUAGE plpgsql
    AS $$
          DECLARE
            ordered_oids INTEGER[] := ARRAY(
              SELECT oid FROM
              (
                WITH RECURSIVE dependency_graph(oid, depth, path, cycle) AS (
                  SELECT oid, 1, ARRAY[oid], FALSE
                  FROM pg_class
                  WHERE relname = view_name
                UNION
                  SELECT
                    rewrites.ev_class,
                    dg.depth + 1,
                    dg.path || rewrites.ev_class,
                    rewrites.ev_class = ANY(dg.path)
                  FROM dependency_graph dg
                    JOIN pg_depend dependents ON dependents.refobjid = dg.oid
                    JOIN pg_rewrite rewrites ON rewrites.oid = dependents.objid
                  WHERE NOT dg.cycle
                )
                SELECT dependency_graph.OID, MIN(depth) AS min_depth FROM dependency_graph GROUP BY dependency_graph.OID ORDER BY min_depth
              ) ordered_dependents
            );
            create_statements TEXT[] := '{}';
            current_statement TEXT;
            view_drop_statement TEXT;
            object_id INT;
          BEGIN
            FOREACH object_id IN ARRAY ordered_oids LOOP
              SELECT
                 (CASE
                    WHEN (SELECT TRUE FROM pg_views WHERE viewname = relname) THEN
                      'CREATE OR REPLACE VIEW ' || pg_class.relname || ' AS ' || pg_get_viewdef(oid)
                    WHEN (SELECT TRUE FROM pg_matviews WHERE matviewname = relname) THEN
                      'CREATE MATERIALIZED VIEW ' || pg_class.relname || ' AS ' || pg_get_viewdef(oid)
                  END)
              INTO current_statement
              FROM pg_class
              WHERE oid = object_id
                    AND pg_class.relname != view_name;
              IF current_statement IS NOT NULL THEN
                create_statements = create_statements || current_statement;
              END IF;
            END LOOP;
            SELECT
              (
                CASE
                  WHEN (SELECT TRUE FROM pg_views WHERE viewname = view_name) THEN
                    'DROP VIEW ' || view_name || ' CASCADE;'
                  WHEN (SELECT TRUE FROM pg_matviews WHERE matviewname = view_name) THEN
                    'DROP MATERIALIZED VIEW ' || view_name || ' CASCADE;'
                END
              )
            INTO view_drop_statement;
            EXECUTE view_drop_statement;
            EXECUTE new_sql;
            FOREACH current_statement IN ARRAY create_statements LOOP
              EXECUTE current_statement;
            END LOOP;
          END;
      $$;


--
-- Name: view_dependencies(name); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION view_dependencies(materialized_view name) RETURNS name[]
    LANGUAGE sql
    AS $$
        WITH RECURSIVE dependency_graph(oid, depth, path, cycle) AS (
          SELECT oid, 1, ARRAY[oid], FALSE
          FROM pg_class
          WHERE relname = materialized_view
          UNION
          SELECT
            dependents.refobjid,
            dg.depth + 1,
            dg.path || dependents.refobjid,
            dependents.refobjid = ANY(dg.path)
          FROM dependency_graph dg
            JOIN pg_rewrite rewrites ON rewrites.ev_class = dg.oid
            JOIN pg_depend dependents ON dependents.objid = rewrites.oid
          WHERE NOT dg.cycle
        ), dependencies AS(
            SELECT
              (SELECT relname FROM pg_class WHERE pg_class.OID = dependency_graph.oid) AS view_name,
              dependency_graph.OID,
              MIN(depth) AS min_depth
            FROM dependency_graph
            GROUP BY dependency_graph.OID ORDER BY min_depth
        )
        SELECT ARRAY(SELECT dependencies.view_name FROM
          dependencies
          JOIN pg_matviews ON pg_matviews.matviewname = dependencies.view_name
        WHERE dependencies.view_name != materialized_view)
        ;
      $$;


SET default_tablespace = '';

--
-- Name: materialized_view_dependencies; Type: MATERIALIZED VIEW; Schema: public; Owner: -; Tablespace: 
--

CREATE MATERIALIZED VIEW materialized_view_dependencies AS
 SELECT pg_matviews.matviewname AS view_name,
    view_dependencies(pg_matviews.matviewname) AS view_dependencies,
    true AS materialized_view
   FROM pg_matviews
  WHERE ((pg_matviews.matviewname <> 'materialized_view_dependencies'::name) AND (pg_matviews.matviewname <> 'all_view_dependencies'::name))
  WITH NO DATA;


--
-- Name: all_view_dependencies; Type: MATERIALIZED VIEW; Schema: public; Owner: -; Tablespace: 
--

CREATE MATERIALIZED VIEW all_view_dependencies AS
 WITH normal_view_dependencies AS (
         SELECT pg_views.viewname AS view_name,
            view_dependencies(pg_views.viewname) AS view_dependencies
           FROM pg_views
        )
 SELECT materialized_view_dependencies.view_name,
    materialized_view_dependencies.view_dependencies,
    materialized_view_dependencies.materialized_view
   FROM materialized_view_dependencies
UNION
 SELECT normal_view_dependencies.view_name,
    normal_view_dependencies.view_dependencies,
    false AS materialized_view
   FROM normal_view_dependencies
  WHERE (array_length(normal_view_dependencies.view_dependencies, 1) > 0)
  WITH NO DATA;


SET default_with_oids = false;

--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying NOT NULL
);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- Name: view_dependencies_update; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER view_dependencies_update ON ddl_command_end 
         WHEN TAG IN ('DROP VIEW', 'DROP MATERIALIZED VIEW', 'CREATE VIEW', 'CREATE MATERIALIZED VIEW', 'ALTER VIEW', 'ALTER MATERIALIZED VIEW') 
   EXECUTE PROCEDURE public.refresh_materialized_view_dependencies();


--
-- PostgreSQL database dump complete
--

SET search_path TO public;

INSERT INTO schema_migrations (version) VALUES ('20150929144540');

INSERT INTO schema_migrations (version) VALUES ('20150929205301');

INSERT INTO schema_migrations (version) VALUES ('20151005150022');

