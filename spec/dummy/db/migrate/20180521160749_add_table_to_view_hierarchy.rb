class AddTableToViewHierarchy < ActiveRecord::Migration[5.0]
  def up
    create_table :table_1 do |t|
      t.string :col_1
    end

    execute <<-SQL
      CREATE OR REPLACE VIEW test_view_4 AS
        SELECT 
          table_1.col_1::TEXT AS col_1,
          'buzz'::TEXT AS col_2
        FROM table_1;
    SQL
  end

  def down
    execute <<-SQL
      CREATE OR REPLACE VIEW test_view_4 AS
        SELECT 
          'fizz'::TEXT AS col_1,
          'buzz'::TEXT AS col_2;
      DROP TABLE table_1;
    SQL
  end
end
