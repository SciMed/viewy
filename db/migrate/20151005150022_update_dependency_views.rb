class UpdateDependencyViews < ActiveRecord::Migration
  def up
    dependency_sql = <<-SQL
      DROP MATERIALIZED VIEW materialized_view_dependencies;
      CREATE MATERIALIZED VIEW materialized_view_dependencies AS
        SELECT
          matviewname AS view_name,
          view_dependencies(matviewname),
          TRUE AS materialized_view
        FROM pg_matviews
        WHERE matviewname != 'materialized_view_dependencies' AND matviewname != 'all_view_dependencies'
      ;
      CREATE MATERIALIZED VIEW all_view_dependencies AS
        WITH normal_view_dependencies AS (
          SELECT viewname AS view_name, view_dependencies(viewname) FROM pg_views
        )
          SELECT * FROM materialized_view_dependencies
        UNION
          SELECT normal_view_dependencies.*, FALSE AS materialized_view FROM normal_view_dependencies WHERE array_length(normal_view_dependencies.view_dependencies, 1) > 0;
    SQL
    execute dependency_sql

    trigger_sql = <<-SQL
      CREATE OR REPLACE FUNCTION refresh_materialized_view_dependencies() RETURNS EVENT_TRIGGER AS $$
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
      $$ LANGUAGE  plpgsql;
    SQL

    execute trigger_sql
  end

  def down
    dependency_sql = <<-SQL
      DROP MATERIALIZED VIEW all_view_dependencies;
      DROP MATERIALIZED VIEW materialized_view_dependencies;

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
    SQL

    execute trigger_sql
  end
end
