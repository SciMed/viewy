class AddNonMaterializedViews < ActiveRecord::Migration[5.0]
  # Creates a hierarchy of views with dependencies with the following graph, where V = view and M = materialized view
  #                   main_view               TV4
  #                 /     |     \
  #               M7     V4      M8
  #             /   \       \   /  \
  #   tv1      M4   V3       M5     M6
  #  /   \    |      \     /       |
  # tv3  tv2  V1      \   /        V2
  #         \ |         M3
  #          M2        |
  #                     M1
  def up
    execute <<-SQL
      CREATE VIEW test_view_2 AS
        SELECT
          false AS is_materialized,
          mat_view_2.label AS col_1
        FROM mat_view_2;
      CREATE VIEW test_view_3 AS
        SELECT 
          'bar'::TEXT AS col_1,
          'baz'::TEXT AS col_2;
      CREATE VIEW test_view_1 AS
        SELECT 
          test_view_2.col_1 || test_view_3.col_1 || test_view_3.col_2 AS result
        FROM test_view_2
        JOIN test_view_3 ON true;
      CREATE VIEW test_view_4 AS
        SELECT 
          'fizz'::TEXT AS col_1,
          'buzz'::TEXT AS col_2;
    SQL
  end

  def down
    execute <<-SQL
      DROP VIEW test_view_4;
      DROP VIEW test_view_1;
      DROP VIEW test_view_2;
      DROP VIEW test_view_3;
    SQL
  end
end
