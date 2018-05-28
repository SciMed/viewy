--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.8
-- Dumped by pg_dump version 9.6.8

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: foo; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA foo;


--
-- Name: all_view_dependencies(name, name); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.all_view_dependencies(materialized_view name, view_schema name) RETURNS text[]
    LANGUAGE sql
    AS $$
        WITH RECURSIVE dependency_graph(oid, depth, path, cycle) AS (
          SELECT pg_class.oid, 1, ARRAY[pg_class.oid], FALSE
          FROM pg_class
            JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.OID AND pg_namespace.nspname = view_schema
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
            JOIN pg_class ON dependents.refobjid = pg_class.OID
            JOIN pg_authid ON pg_class.relowner = pg_authid.OID AND pg_authid.rolname != 'postgres'
          WHERE NOT dg.cycle AND pg_class.relkind IN ('m', 'v')
        ), dependencies AS(
            SELECT
            (
              SELECT
               nspname || '.' || relname
              FROM pg_class
                JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.OID
              WHERE pg_class.OID = dependency_graph.oid
            ) AS view_name,
            (
              SELECT
               nspname
              FROM pg_class
                JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.OID
              WHERE pg_class.OID = dependency_graph.oid
            ) AS schema_name,
            (
              SELECT
               relname
              FROM pg_class
              WHERE pg_class.OID = dependency_graph.oid
            ) AS name,
            dependency_graph.OID,
            MIN(depth) AS min_depth
          FROM dependency_graph
          GROUP BY dependency_graph.OID
          ORDER BY min_depth
        )
        SELECT ARRAY(
          SELECT dependencies.view_name 
          FROM dependencies
            LEFT JOIN pg_matviews  
              ON pg_matviews.matviewname = dependencies.name 
              AND pg_matviews.schemaname = dependencies.schema_name
            LEFT JOIN pg_views 
              ON pg_views.viewname = dependencies.name 
              AND pg_matviews.schemaname = dependencies.schema_name
          WHERE dependencies.view_name != (view_schema || '.' || materialized_view)
        )
        ;
      $$;


--
-- Name: refresh_materialized_view_dependencies(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_materialized_view_dependencies() RETURNS event_trigger
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

CREATE FUNCTION public.replace_view(view_name text, new_sql text) RETURNS void
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
            index_statements TEXT[] := '{}';
            current_index_statements TEXT[] := '{}';
            current_statement TEXT;
            current_index_statement TEXT;
            view_drop_statement TEXT;
            object_id INT;
          BEGIN
            FOREACH object_id IN ARRAY ordered_oids LOOP
              SELECT
                 (CASE
                    WHEN (SELECT TRUE FROM pg_views WHERE viewname = relname) THEN
                      'CREATE OR REPLACE VIEW ' || pg_class.relname || ' AS ' || pg_get_viewdef(oid)
                    WHEN (SELECT TRUE FROM pg_matviews WHERE matviewname = relname) THEN
                      'CREATE MATERIALIZED VIEW ' || pg_class.relname || ' AS ' || TRIM(TRAILING ';' FROM pg_get_viewdef(oid)) || ' WITH NO DATA'
                  END)
              INTO current_statement
              FROM pg_class
              WHERE oid = object_id
                    AND pg_class.relname != view_name;
              IF current_statement IS NOT NULL THEN
                create_statements = create_statements || current_statement;
                SELECT INTO current_index_statements array_agg(pg_indexes.indexdef)
                  FROM pg_indexes
                    JOIN pg_class ON pg_class.relname = pg_indexes.tablename
                  WHERE pg_class.OID = object_id;
                index_statements := array_cat(index_statements,  current_index_statements);
              END IF;
            END LOOP;
            ALTER EVENT TRIGGER view_dependencies_update DISABLE;
            SELECT INTO current_index_statements array_agg(pg_indexes.indexdef)
              FROM pg_indexes
              WHERE pg_indexes.tablename = view_name;
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
            IF index_statements IS NOT NULL THEN
              FOREACH current_index_statement IN ARRAY index_statements LOOP
                EXECUTE current_index_statement;
              END LOOP;
            END IF;
            IF current_index_statements IS NOT NULL THEN
              FOREACH current_index_statement IN ARRAY current_index_statements LOOP
                EXECUTE current_index_statement;
              END LOOP;
            END IF;
            ALTER EVENT TRIGGER view_dependencies_update ENABLE ALWAYS;
          END;
      $$;


--
-- Name: view_dependencies(name, name); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.view_dependencies(materialized_view name, view_schema name) RETURNS text[]
    LANGUAGE sql
    AS $$
        WITH RECURSIVE dependency_graph(oid, depth, path, cycle) AS (
          SELECT pg_class.oid, 1, ARRAY[pg_class.oid], FALSE
          FROM pg_class
            JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.OID AND pg_namespace.nspname = view_schema
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
            (
              SELECT
               nspname || '.' || relname
              FROM pg_class
                JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.OID
              WHERE pg_class.OID = dependency_graph.oid
            ) AS view_name,
            (
              SELECT
               nspname
              FROM pg_class
                JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.OID
              WHERE pg_class.OID = dependency_graph.oid
            ) AS schema_name,
            (
              SELECT
               relname
              FROM pg_class
              WHERE pg_class.OID = dependency_graph.oid
            ) AS name,
            dependency_graph.OID,
            MIN(depth) AS min_depth
          FROM dependency_graph
          GROUP BY dependency_graph.OID
          ORDER BY min_depth
        )
        SELECT ARRAY(
          SELECT dependencies.view_name
          FROM dependencies
            JOIN pg_matviews ON pg_matviews.matviewname = dependencies.name AND pg_matviews.schemaname = dependencies.schema_name
          WHERE dependencies.view_name != (view_schema || '.' || materialized_view) 
        )
        ;
      $$;


SET default_tablespace = '';

--
-- Name: mat_view_1; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.mat_view_1 AS
 SELECT 'M1'::text AS label,
    'M1'::text AS name,
    1 AS code
  WITH NO DATA;


--
-- Name: mat_view; Type: MATERIALIZED VIEW; Schema: foo; Owner: -
--

CREATE MATERIALIZED VIEW foo.mat_view AS
 SELECT mat_view_1.label
   FROM public.mat_view_1
  WITH NO DATA;


--
-- Name: test_view_3; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.test_view_3 AS
 SELECT 'bar'::text AS col_1,
    'baz'::text AS col_2;


--
-- Name: test_view_3; Type: VIEW; Schema: foo; Owner: -
--

CREATE VIEW foo.test_view_3 AS
 SELECT test_view_3.col_1,
    'baz'::text AS col_2
   FROM public.test_view_3;


--
-- Name: mat_view_2; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.mat_view_2 AS
 SELECT 'M2'::text AS label,
    'M2'::text AS name,
    2 AS code
  WITH NO DATA;


--
-- Name: mat_view_3; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.mat_view_3 AS
 SELECT (mv1.label || ' + M3'::text) AS label,
    mv1.code AS old_code,
    (((mv1.code)::text || '3'::text))::integer AS code
   FROM public.mat_view_1 mv1
  WITH NO DATA;


--
-- Name: view_1; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_1 AS
 SELECT (mv2.label || ' + V1'::text) AS label,
    mv2.code,
    'V1'::text AS name
   FROM public.mat_view_2 mv2;


--
-- Name: mat_view_4; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.mat_view_4 AS
 SELECT v1.code AS old_code,
    (v1.label || ' + M4'::text) AS label,
    (((v1.code)::text || '4'::text))::integer AS code,
    'M4'::text AS name
   FROM public.view_1 v1
  WITH NO DATA;


--
-- Name: mat_view_5; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.mat_view_5 AS
 SELECT (((mv3.code)::text || '5'::text))::integer AS code,
    (mv3.label || ' + M5'::text) AS label,
    mv3.code AS old_code,
    'M5'::text AS name
   FROM public.mat_view_3 mv3
  WITH NO DATA;


--
-- Name: view_2; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_2 AS
 SELECT 'V2'::text AS label,
    222 AS code,
    'V2'::text AS name;


--
-- Name: mat_view_6; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.mat_view_6 AS
 SELECT v2.code AS old_code,
    (v2.label || ' + M6'::text) AS label,
    (((v2.code)::text || '6'::text))::integer AS code,
    'M6'::text AS name
   FROM public.view_2 v2
  WITH NO DATA;


--
-- Name: view_3; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_3 AS
 SELECT (mv3.label || ' + V3'::text) AS label,
    mv3.code,
    mv3.old_code,
    'V3'::text AS name
   FROM public.mat_view_3 mv3;


--
-- Name: mat_view_7; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.mat_view_7 AS
 SELECT (((v3.code)::text || '7'::text))::integer AS code,
    (v3.label || ' + M7'::text) AS label,
    v3.code AS old_code,
    'M7'::text AS name
   FROM public.view_3 v3
UNION
 SELECT (((mv4.code)::text || '7'::text))::integer AS code,
    (mv4.label || ' + M7'::text) AS label,
    mv4.code AS old_code,
    'M7'::text AS name
   FROM public.mat_view_4 mv4
  WITH NO DATA;


--
-- Name: mat_view_8; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.mat_view_8 AS
 SELECT (((mv5.code)::text || '8'::text))::integer AS code,
    (mv5.label || ' + M8'::text) AS label,
    mv5.code AS old_code,
    'M8'::text AS name
   FROM public.mat_view_5 mv5
UNION
 SELECT (((mv6.code)::text || '8'::text))::integer AS code,
    (mv6.label || ' + M8'::text) AS label,
    mv6.code AS old_code,
    'M8'::text AS name
   FROM public.mat_view_6 mv6
  WITH NO DATA;


--
-- Name: main_view; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.main_view AS
 SELECT (((mv7.code)::text || '9'::text))::integer AS code,
    (mv7.label || ' + main'::text) AS label,
    mv7.code AS old_code,
    'main'::text AS name
   FROM public.mat_view_7 mv7
UNION
 SELECT (((mv8.code)::text || '9'::text))::integer AS code,
    (mv8.label || ' + main'::text) AS label,
    mv8.code AS old_code,
    'main'::text AS name
   FROM public.mat_view_8 mv8
  WITH NO DATA;


--
-- Name: other_view; Type: VIEW; Schema: foo; Owner: -
--

CREATE VIEW foo.other_view AS
 SELECT main_view.label AS col_1,
    test_view_3.col_2
   FROM foo.test_view_3,
    public.main_view;


--
-- Name: all_view_dependencies; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.all_view_dependencies AS
 WITH normal_view_dependencies AS (
         SELECT (((pg_views.schemaname)::text || '.'::text) || (pg_views.viewname)::text) AS view_name,
            public.all_view_dependencies(pg_views.viewname, pg_views.schemaname) AS view_dependencies
           FROM pg_views
          WHERE (pg_views.viewowner <> 'postgres'::name)
        ), matview_dependencies AS (
         SELECT (((pg_matviews.schemaname)::text || '.'::text) || (pg_matviews.matviewname)::text) AS view_name,
            public.all_view_dependencies(pg_matviews.matviewname, pg_matviews.schemaname) AS view_dependencies
           FROM pg_matviews
          WHERE (pg_matviews.matviewowner <> 'postgres'::name)
        )
 SELECT matview_dependencies.view_name,
    matview_dependencies.view_dependencies,
    true AS materialized_view
   FROM matview_dependencies
UNION
 SELECT normal_view_dependencies.view_name,
    normal_view_dependencies.view_dependencies,
    false AS materialized_view
   FROM normal_view_dependencies
  WITH NO DATA;


SET default_with_oids = false;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: materialized_view_dependencies; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.materialized_view_dependencies AS
 SELECT (((pg_matviews.schemaname)::text || '.'::text) || (pg_matviews.matviewname)::text) AS view_name,
    public.view_dependencies(pg_matviews.matviewname, pg_matviews.schemaname) AS view_dependencies,
    true AS materialized_view
   FROM pg_matviews
  WHERE ((pg_matviews.matviewname <> 'materialized_view_dependencies'::name) AND (pg_matviews.matviewname <> 'all_view_dependencies'::name))
  WITH NO DATA;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: table_1; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.table_1 (
    id integer NOT NULL,
    col_1 character varying
);


--
-- Name: table_1_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.table_1_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: table_1_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.table_1_id_seq OWNED BY public.table_1.id;


--
-- Name: test_view_2; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.test_view_2 AS
 SELECT false AS is_materialized,
    mat_view_2.label AS col_1
   FROM public.mat_view_2;


--
-- Name: test_view_1; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.test_view_1 AS
 SELECT ((test_view_2.col_1 || test_view_3.col_1) || test_view_3.col_2) AS result
   FROM (public.test_view_2
     JOIN public.test_view_3 ON (true));


--
-- Name: test_view_4; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.test_view_4 AS
 SELECT (table_1.col_1)::text AS col_1,
    'buzz'::text AS col_2
   FROM public.table_1;


--
-- Name: view_4; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_4 AS
 SELECT (mv5.label || ' + V4'::text) AS label,
    mv5.code,
    mv5.old_code,
    'V4'::text AS name
   FROM public.mat_view_5 mv5;


--
-- Name: table_1 id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_1 ALTER COLUMN id SET DEFAULT nextval('public.table_1_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: table_1 table_1_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_1
    ADD CONSTRAINT table_1_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

SET search_path TO public,foo;

INSERT INTO "schema_migrations" (version) VALUES
('20150929144540'),
('20150929205301'),
('20151005150022'),
('20160512173021'),
('20160513141153'),
('20171027181119'),
('20180518193352'),
('20180518200311'),
('20180521160749'),
('20180521162238'),
('20180525142127'),
('20180528164845'),
('20180528165706'),
('20180528211227');



        CREATE EVENT TRIGGER view_dependencies_update
        ON DDL_COMMAND_END
        WHEN TAG IN ('DROP VIEW', 'DROP MATERIALIZED VIEW', 'CREATE VIEW', 'CREATE MATERIALIZED VIEW', 'ALTER VIEW', 'ALTER MATERIALIZED VIEW')
        EXECUTE PROCEDURE refresh_materialized_view_dependencies();
