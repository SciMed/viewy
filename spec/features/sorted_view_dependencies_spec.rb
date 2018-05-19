require 'rails_helper'

describe Viewy do
  describe '#view_names_in_dependency_order' do
    it 'returns the names of all views in the system in a topologically safe order' do
      expected_view_names = %w(
        mat_view_2
        view_1
        mat_view_1
        mat_view_3
        view_3
        view_2
        mat_view_6
        mat_view_5
        mat_view_8
        mat_view_4
        mat_view_7
        main_view
        materialized_view_dependencies
        test_view_4
        test_view_2
        test_view_3
        test_view_1
        view_4
        all_view_dependencies
      )
      expect(Viewy.view_names_in_dependency_order).to eql expected_view_names
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
      views.delete 'all_view_dependencies'
      views.delete  'materialized_view_dependencies'

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
