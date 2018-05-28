class AddViewsInOtherSchema < ActiveRecord::Migration[5.0]
  def up
    execute <<-SQL
      CREATE SCHEMA foo;
      CREATE VIEW foo.test_view_3 AS
        SELECT 
          public.test_view_3.col_1 AS col_1,
          'baz'::TEXT AS col_2
        FROM test_view_3;
      CREATE VIEW foo.other_view AS 
        SELECT 
          main_view.label AS col_1,
          foo.test_view_3.col_2 AS col_2
        FROM foo.test_view_3, public.main_view;
    SQL
  end

  def down
    execute <<-SQL
      DROP VIEW foo.other_view;
      DROP VIEW foo.test_view_3;
      DROP SCHEMA foo;
    SQL
  end
end
