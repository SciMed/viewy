class AddSchemaNameToViewDependencies < ActiveRecord::Migration[5.2]
  def up
    drop_statement = <<-SQL
      DROP MATERIALIZED VIEW all_view_dependencies;
      DROP MATERIALIZED VIEW materialized_view_dependencies;
      DROP FUNCTION all_view_dependencies(name);
      DROP FUNCTION view_dependencies(name);
    SQL
    execute(drop_statement)

    view_dependencies_function_sql = <<-SQL
      CREATE OR REPLACE FUNCTION view_dependencies(materialized_view NAME)
        RETURNS TEXT[]
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
              pg_class.relname AS view_name,
              schemas.nspname AS schema_name,
              dependency_graph.OID,
              MIN(depth) AS min_depth
            FROM dependency_graph
            LEFT JOIN pg_class ON pg_class.OID = dependency_graph.oid
            LEFT JOIN pg_catalog.pg_namespace schemas ON schemas.oid = pg_class.relnamespace
            GROUP BY dependency_graph.OID, pg_class.relname, schemas.nspname
            ORDER BY min_depth
        )
        SELECT ARRAY(SELECT dependencies.schema_name || '.' || dependencies.view_name FROM
          dependencies
          JOIN pg_matviews
            ON pg_matviews.matviewname = dependencies.view_name
              AND pg_matviews.schemaname = dependencies.schema_name
        WHERE dependencies.view_name != materialized_view)
        ;
      $$ LANGUAGE SQL;
    SQL
    execute(view_dependencies_function_sql)

    all_view_dependencies_function_sql = <<-SQL
      CREATE OR REPLACE FUNCTION all_view_dependencies(materialized_view NAME)
        RETURNS TEXT[]
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
            JOIN pg_class ON dependents.refobjid = pg_class.OID
            JOIN pg_authid ON pg_class.relowner = pg_authid.OID AND pg_authid.rolname != 'postgres'
          WHERE NOT dg.cycle AND pg_class.relkind IN ('m', 'v')
        ), dependencies AS(
            SELECT
              pg_class.relname AS view_name,
              schemas.nspname AS schema_name,
              dependency_graph.OID,
              MIN(depth) AS min_depth
            FROM dependency_graph
            LEFT JOIN pg_class ON pg_class.OID = dependency_graph.oid
            LEFT JOIN pg_catalog.pg_namespace schemas ON schemas.oid = pg_class.relnamespace
            GROUP BY dependency_graph.OID, pg_class.relname, schemas.nspname
            ORDER BY min_depth
        )
        SELECT ARRAY(
          SELECT dependencies.schema_name || '.' || dependencies.view_name
          FROM dependencies
            LEFT JOIN pg_matviews
                   ON pg_matviews.matviewname = dependencies.view_name
                     AND pg_matviews.schemaname = dependencies.schema_name
            LEFT JOIN pg_views
                   ON pg_views.viewname = dependencies.view_name
                     AND pg_views.schemaname = dependencies.schema_name
          WHERE dependencies.view_name != materialized_view
        )
        ;
      $$ LANGUAGE SQL;
    SQL
    execute(all_view_dependencies_function_sql)

    all_view_dependency_sql = <<-SQL
      CREATE MATERIALIZED VIEW all_view_dependencies AS
        WITH normal_view_dependencies AS (
          SELECT
            schemaname || '.' || viewname AS view_name,
            all_view_dependencies(viewname) AS view_dependencies
          FROM pg_views
          WHERE viewowner != 'postgres'
        ),
         matview_dependencies AS (
          SELECT
            schemaname || '.' || matviewname AS view_name,
            all_view_dependencies(matviewname)  AS view_dependencies
          FROM pg_matviews
          WHERE matviewowner != 'postgres'
        )
          SELECT matview_dependencies.*, TRUE as materialized_view FROM matview_dependencies
        UNION
          SELECT normal_view_dependencies.*, FALSE AS materialized_view FROM normal_view_dependencies;
    SQL
    execute(all_view_dependency_sql)

    materialized_view_dependency_sql = <<-SQL
      CREATE MATERIALIZED VIEW materialized_view_dependencies AS
        SELECT
          schemaname || '.' || matviewname AS view_name,
          view_dependencies(matviewname),
          TRUE AS materialized_view
        FROM pg_matviews
        WHERE matviewname != 'materialized_view_dependencies' AND matviewname != 'all_view_dependencies'
      ;
    SQL
    execute(materialized_view_dependency_sql)
  end

  def down
    drop_statement = <<-SQL
      DROP MATERIALIZED VIEW all_view_dependencies;
      DROP MATERIALIZED VIEW materialized_view_dependencies;
      DROP FUNCTION all_view_dependencies(name);
      DROP FUNCTION view_dependencies(name);
    SQL
    execute(drop_statement)

    view_dependencies_function_sql = <<-SQL
      CREATE OR REPLACE FUNCTION view_dependencies(materialized_view NAME)
        RETURNS NAME[]
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
      $$ LANGUAGE SQL;
    SQL
    execute(view_dependencies_function_sql)

    all_view_dependencies_function_sql = <<-SQL
      CREATE OR REPLACE FUNCTION all_view_dependencies(materialized_view NAME)
        RETURNS NAME[]
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
            JOIN pg_class ON dependents.refobjid = pg_class.OID
            JOIN pg_authid ON pg_class.relowner = pg_authid.OID AND pg_authid.rolname != 'postgres'
          WHERE NOT dg.cycle AND pg_class.relkind IN ('m', 'v')
        ), dependencies AS(
            SELECT
              (SELECT relname FROM pg_class WHERE pg_class.OID = dependency_graph.oid) AS view_name,
              dependency_graph.OID,
              MIN(depth) AS min_depth
            FROM dependency_graph
            GROUP BY dependency_graph.OID ORDER BY min_depth
        )
        SELECT ARRAY(
          SELECT dependencies.view_name
          FROM dependencies
            LEFT JOIN pg_matviews ON pg_matviews.matviewname = dependencies.view_name
            LEFT JOIN pg_views ON pg_views.viewname = dependencies.view_name
          WHERE dependencies.view_name != materialized_view
        )
        ;
      $$ LANGUAGE SQL;
    SQL
    execute(all_view_dependencies_function_sql)

    all_view_dependency_sql = <<-SQL
      CREATE MATERIALIZED VIEW all_view_dependencies AS
        WITH normal_view_dependencies AS (
          SELECT
            viewname AS view_name,
            all_view_dependencies(viewname) AS view_dependencies
          FROM pg_views
          WHERE viewowner != 'postgres'
        ),
         matview_dependencies AS (
          SELECT
            matviewname AS view_name,
            all_view_dependencies(matviewname)  AS view_dependencies
          FROM pg_matviews
          WHERE matviewowner != 'postgres'
        )
          SELECT matview_dependencies.*, TRUE as materialized_view FROM matview_dependencies
        UNION
          SELECT normal_view_dependencies.*, FALSE AS materialized_view FROM normal_view_dependencies;
    SQL
    execute(all_view_dependency_sql)

    materialized_view_dependency_sql = <<-SQL
      CREATE MATERIALIZED VIEW materialized_view_dependencies AS
        SELECT
          matviewname AS view_name,
          view_dependencies(matviewname),
          TRUE AS materialized_view
        FROM pg_matviews
        WHERE matviewname != 'materialized_view_dependencies' AND matviewname != 'all_view_dependencies'
      ;
    SQL
    execute(materialized_view_dependency_sql)
  end
end
