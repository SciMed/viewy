class AddMaterializedViewInFooNamespace < ActiveRecord::Migration[5.0]
  def up
    execute <<~SQL
      CREATE MATERIALIZED VIEW foo.mat_view AS
      SELECT 
        public.mat_view_1.label AS label
       FROM mat_view_1;
    SQL
  end

  def down
    execute <<~SQL
      DROP MATERIALIZED VIEW foo.mat_view
    SQL
  end
end
