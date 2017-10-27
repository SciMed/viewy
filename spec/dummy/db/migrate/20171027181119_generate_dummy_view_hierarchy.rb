class GenerateDummyViewHierarchy < ActiveRecord::Migration
  # Creates a hierarchy of views with dependencies with the following graph, where V = view and M = materialized view
  #
  #           main_view
  #         /     |     \
  #       M7     V4      M8
  #     /   \       \   /  \
  #    M4   V3       M5     M6
  #    |      \     /       |
  #    V1      \   /        V2
  #    |         M3
  #    M2        |
  #             M1
  def up
    execute <<-SQL
      CREATE MATERIALIZED VIEW mat_view_1 AS
        SELECT 
          'M1'::TEXT AS label,
          'M1'::TEXT AS "name",
          1        AS code
      ;

      CREATE MATERIALIZED VIEW mat_view_2 AS
        SELECT 
          'M2'::TEXT AS label,
          'M2'::TEXT AS "name",          
          2        AS code
      ;

      CREATE VIEW view_1 AS
        SELECT 
          mv2.label || ' + V1' AS label,
          mv2.code             AS code,
          'V1'::TEXT           AS "name"
        FROM mat_view_2 mv2
      ;

      CREATE VIEW view_2 AS
        SELECT 
          'V2'::TEXT   as label,
          222          as code,
          'V2'::TEXT   AS "name"
      ;

      CREATE MATERIALIZED VIEW mat_view_3 AS
        SELECT 
          mv1.label || ' + M3'          AS label,
          mv1.code                      AS old_code,
          (mv1.code::TEXT || '3')::INT  AS code
        FROM mat_view_1 mv1
      ;

      CREATE MATERIALIZED VIEW mat_view_4 AS
        SELECT
          v1.code                      AS old_code,
          v1.label || ' + M4'             AS label,
          (v1.code::TEXT || '4')::INT  AS code, 
          'M4'::TEXT                   AS "name"
        FROM view_1 v1           
      ;

      CREATE VIEW view_3 AS
        SELECT 
          mv3.label || ' + V3'     AS label,
          mv3.code                 AS code,
          mv3.old_code             AS old_code,
          'V3'::TEXT               AS "name"
        FROM mat_view_3 mv3
      ;

      CREATE MATERIALIZED VIEW mat_view_5 AS
        SELECT
          (mv3.code::TEXT || '5')::INT  AS code ,
          mv3.label || ' + M5'          AS label,
          mv3.code                      AS old_code,
          'M5'::TEXT                    AS "name"
        
        FROM mat_view_3 mv3           
      ;

      CREATE MATERIALIZED VIEW mat_view_6 AS
        SELECT
          v2.code                      AS old_code,
          v2.label || ' + M6'             AS label,
          (v2.code::TEXT || '6')::INT  AS code, 
          'M6'::TEXT                   AS "name"
        FROM view_2 v2          
      ;

      CREATE MATERIALIZED VIEW mat_view_7 AS
        SELECT
          (v3.code::TEXT || '7')::INT  AS code, 
          v3.label || ' + M7'          AS label,
          v3.code                      AS old_code,
          'M7'::TEXT                   AS "name"
        FROM view_3 v3     
        UNION
        SELECT     
          (mv4.code::TEXT || '7')::INT  AS code,
          mv4.label || ' + M7'          AS label,
          mv4.code                      AS old_code,
          'M7'::TEXT                    AS "name"
        FROM mat_view_4 mv4;
      ;

      CREATE VIEW view_4 AS
        SELECT 
          mv5.label || ' + V4'     AS label,
          mv5.code                 AS code,
          mv5.old_code             AS old_code,
          'V4'::TEXT               AS "name"
        FROM mat_view_5 mv5
      ;

      CREATE MATERIALIZED VIEW mat_view_8 AS
        SELECT
          (mv5.code::TEXT || '8')::INT  AS code ,
          mv5.label || ' + M8'          AS label,
          mv5.code                      AS old_code,
          'M8'::TEXT                    AS "name"
        FROM mat_view_5 mv5
        UNION
        SELECT
          (mv6.code::TEXT || '8')::INT  AS code ,
          mv6.label || ' + M8'          AS label,
          mv6.code                      AS old_code,
          'M8'::TEXT                    AS "name"
        FROM mat_view_6 mv6;
      ;

      CREATE MATERIALIZED VIEW main_view AS
        SELECT
          (mv7.code::TEXT || '9')::INT    AS code ,
          mv7.label || ' + main'          AS label,
          mv7.code                        AS old_code,
          'main'::TEXT                    AS "name"
        FROM mat_view_7 mv7
        UNION
        SELECT
          (mv8.code::TEXT || '9')::INT  AS code ,
          mv8.label || ' + main'          AS label,
          mv8.code                      AS old_code,
          'main'::TEXT                    AS "name"
        FROM mat_view_8 mv8;
      ;
    SQL
  end

  def down
    execute <<-SQL
      DROP MATERIALIZED VIEW main_view; 
      DROP MATERIALIZED VIEW mat_view_8; 
      DROP VIEW view_4; 
      DROP MATERIALIZED VIEW mat_view_7; 
      DROP MATERIALIZED VIEW mat_view_6; 
      DROP MATERIALIZED VIEW mat_view_5; 
      DROP VIEW view_3; 
      DROP MATERIALIZED VIEW mat_view_4; 
      DROP MATERIALIZED VIEW mat_view_3; 
      DROP VIEW view_2; 
      DROP VIEW view_1; 
      DROP MATERIALIZED VIEW mat_view_2; 
      DROP MATERIALIZED VIEW mat_view_1;
    SQL
  end
end
