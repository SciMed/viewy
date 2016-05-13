class AddIndexRecreation < ActiveRecord::Migration
  def up
    function_sql = <<-SQL
      CREATE OR REPLACE FUNCTION replace_view(view_name TEXT, new_sql TEXT) RETURNS VOID AS $$
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
      $$ LANGUAGE plpgsql;
    SQL
    execute function_sql
  end

  def down
    function_sql = <<-SQL
      CREATE OR REPLACE FUNCTION replace_view(view_name TEXT, new_sql TEXT) RETURNS VOID AS $$
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
                      'CREATE MATERIALIZED VIEW ' || pg_class.relname || ' AS ' || TRIM(TRAILING ';' FROM pg_get_viewdef(oid)) || ' WITH NO DATA'
                  END)
              INTO current_statement
              FROM pg_class
              WHERE oid = object_id
                    AND pg_class.relname != view_name;
              IF current_statement IS NOT NULL THEN
                create_statements = create_statements || current_statement;
              END IF;
            END LOOP;
            ALTER EVENT TRIGGER view_dependencies_update DISABLE;
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
            ALTER EVENT TRIGGER view_dependencies_update ENABLE ALWAYS;
          END;
      $$ LANGUAGE plpgsql;
    SQL
    execute function_sql
  end
end
