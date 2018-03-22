class AddViewDependencies < ActiveRecord::Migration[5.0]
  def up
    view_dependency_function_sql = <<-SQL
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
    execute view_dependency_function_sql

    dependency_sql = <<-SQL
      CREATE MATERIALIZED VIEW materialized_view_dependencies AS
        WITH normal_view_dependencies AS (
          SELECT viewname AS view_name, view_dependencies(viewname) FROM pg_views
        )
          SELECT matviewname AS view_name, view_dependencies(matviewname), TRUE AS materialized_view FROM pg_matviews WHERE matviewname != 'materialized_view_dependencies'
        UNION
          SELECT normal_view_dependencies.*, FALSE AS materialized_view FROM normal_view_dependencies WHERE array_length(normal_view_dependencies.view_dependencies, 1) > 0;
      ;
    SQL
    execute dependency_sql

    trigger_sql = <<-SQL
      CREATE OR REPLACE FUNCTION refresh_materialized_view_dependencies() RETURNS EVENT_TRIGGER AS $$
        DECLARE
          view_exists BOOLEAN := (SELECT TRUE FROM pg_class WHERE pg_class.relname = 'materialized_view_dependencies' AND pg_class.relkind = 'm');
        BEGIN
          RAISE NOTICE 'refreshing view dependency hierarchy';
          IF view_exists THEN
            REFRESH MATERIALIZED VIEW materialized_view_dependencies;
          END IF;
        END
      $$ LANGUAGE  plpgsql;

      CREATE EVENT TRIGGER view_dependencies_update
        ON DDL_COMMAND_END
        WHEN TAG IN ('DROP VIEW', 'DROP MATERIALIZED VIEW', 'CREATE VIEW', 'CREATE MATERIALIZED VIEW', 'ALTER VIEW', 'ALTER MATERIALIZED VIEW')
        EXECUTE PROCEDURE refresh_materialized_view_dependencies();
    SQL

    execute trigger_sql
  end

  def down
    down_sql = <<-SQL
      DROP MATERIALIZED VIEW materialized_view_dependencies;
      DROP FUNCTION view_dependencies(materialized_view NAME);
      DROP EVENT TRIGGER view_dependencies_update;
      DROP FUNCTION refresh_materialized_view_dependencies();
    SQL
    execute down_sql
  end
end
