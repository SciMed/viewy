require 'rails_helper'

describe Viewy do
  describe '#view_names_in_dependency_order' do
    it 'returns the names of all views in the system in a topologically safe order' do
      dependency_orders = {
        'public.mat_view_3' => %w[public.mat_view_1],
        'public.view_1'     => %w[public.mat_view_2],
        'public.mat_view_4' => %w[public.view_1],
        'public.mat_view_5' => %w[public.mat_view_3],
        'public.mat_view_6' => %w[public.view_2],
        'public.view_3'     => %w[public.mat_view_3],
        'public.mat_view_7' => %w[public.view_3 public.mat_view_4],
        'public.mat_view_8' => %w[public.mat_view_5 public.mat_view_6],
        'public.main_view'  => %w[public.mat_view_7 public.mat_view_8]
      }

      expected_view_names = %w[
        public.mat_view_2
        public.view_1
        public.mat_view_1
        public.mat_view_3
        public.view_3
        public.view_2
        public.mat_view_6
        public.mat_view_5
        public.mat_view_8
        public.mat_view_4
        public.mat_view_7
        public.main_view
        public.materialized_view_dependencies
        public.test_view_4
        public.test_view_2
        public.test_view_3
        public.test_view_1
        public.view_4
        public.all_view_dependencies
      ]

      result = Viewy.view_names_in_dependency_order
      expect(result).to match_array(expected_view_names)
      dependency_orders.each do |view, dependencies|
        dependencies.each do |dependency|
          expect(result.index(dependency)).to be < result.index(view)
        end
      end

      result = ActiveRecord::Base.connection.execute <<-SQL
        SELECT
          matviewname,
          'CREATE MATERIALIZED VIEW AS ' || definition
        FROM pg_matviews WHERE matviewowner != 'postgres';
      SQL
      views = {}
      result.values.each do |tuple|
        views[tuple[0]] = tuple[1]
      end
      result = ActiveRecord::Base.connection.execute <<-SQL
        SELECT
          viewname,
          'CREATE VIEW AS ' || definition
        FROM pg_views
        WHERE viewowner != 'postgres';
      SQL
      result.values.each do |tuple|
        views[tuple[0]] = tuple[1]
      end
      views.delete 'public.all_view_dependencies'
      views.delete 'public.materialized_view_dependencies'

      expect {
        Viewy.view_names_in_dependency_order.reverse.each do |name|
          next unless views[name]
          statement = if views[name].match?(/MATERIALIZED/)
            "DROP MATERIALIZED VIEW #{name};"
          else
            "DROP VIEW #{name};"
          end
          ActiveRecord::Base.connection.execute statement
        end
      }.not_to raise_error

      expect {
        Viewy.view_names_in_dependency_order.each do |name|
          next unless views[name]
          ActiveRecord::Base.connection.execute views[name]
        end
      }.not_to raise_error
    end
  end
end
