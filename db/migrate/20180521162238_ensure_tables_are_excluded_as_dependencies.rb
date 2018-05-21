class EnsureTablesAreExcludedAsDependencies < ActiveRecord::Migration[5.0]
  def up
    view_dependency_function_sql = <<-SQL
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
    execute view_dependency_function_sql
    dependency_sql = <<-SQL
      DROP MATERIALIZED VIEW all_view_dependencies;
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
    execute dependency_sql
  end

  def down
    view_dependency_function_sql = <<-SQL
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
          WHERE NOT dg.cycle
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
    execute view_dependency_function_sql
    dependency_sql = <<-SQL
      DROP MATERIALIZED VIEW all_view_dependencies;
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
    execute dependency_sql
  end
end
