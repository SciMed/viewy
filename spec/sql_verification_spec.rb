require 'rails_helper'

# NOTE: for tests in this file, refer to dummy/db/migrate/20171027181119_generate_dummy_view_hierarchy.rb for
# the shape of the view hierarchy

describe 'Viewy sql functions' do
  describe 'view_dependencies' do
    context 'there are no views in the hierarchy' do
      it 'returns the dependencies for the passed view' do
        result = ActiveRecord::Base.connection.execute <<-SQL
          SELECT view_dependencies('mat_view_5');
        SQL
        dependencies = '{mat_view_3,mat_view_1}'

        expect(result.values[0][0]).to eql dependencies
      end
    end
    context 'there no views in the hierarchy' do
      it 'returns the materialized dependencies for the passed view' do
        result = ActiveRecord::Base.connection.execute <<-SQL
          SELECT view_dependencies('mat_view_7');
        SQL
        dependencies_first_tier = %w(mat_view_4 mat_view_3)
        dependencies_second_tier = %w(mat_view_2 mat_view_1)

        dependencies_from_server = result.values[0][0]
        dependencies_from_server = dependencies_from_server[1..dependencies_from_server.length - 2].split(',')

        # So long as all dependencies from the server are present in the correct tier ordering does not matter,
        # and is not stable from Postgres
        expect(dependencies_from_server[0..1]).to match_array dependencies_first_tier
        expect(dependencies_from_server[2..3]).to match_array dependencies_second_tier
      end
    end
  end

  describe 'replace_view' do
    it 'replaces the a view in the middle of the hierarchy' do
      expect {
        ActiveRecord::Base.connection.execute <<-SQL
          SELECT replace_view('mat_view_7', $$
            CREATE MATERIALIZED VIEW mat_view_7 AS
              SELECT
                (v3.code::TEXT || '7')::INT    AS code, 
                v3.label || 'M7.1'             AS label,
                v3.code                        AS old_code,
                'M7.1'::TEXT                   AS "name"
              FROM view_3 v3     
              UNION
              SELECT     
                (mv4.code::TEXT || '7')::INT  AS code ,
                mv4.label || ' + M7.1'        AS label,
                mv4.code                      AS old_code,
                'M7.1'::TEXT                  AS "name"
              FROM mat_view_4 mv4;
        ;
          $$)
        SQL
      }.to change {
        Viewy::DependencyManager.new.refresh_all_materialized_views
        ActiveRecord::Base.connection.execute("SELECT * FROM main_view WHERE code=2479").values[0][1].include?('M7.1')
      }.from(false).to(true)
    end
  end

  describe 'refresh_materialized_view_dependencies' do
    before :all do
      ActiveRecord::Base.connection.execute <<-SQL
        REFRESH MATERIALIZED VIEW materialized_view_dependencies;
        REFRESH MATERIALIZED VIEW all_view_dependencies;
      SQL
    end

    after do
      ActiveRecord::Base.connection.execute <<-SQL
        DROP MATERIALIZED VIEW foo;
        DROP VIEW bar;
        DROP MATERIALIZED VIEW baz;
      SQL
    end
    it 'refreshes the dependency information' do
      # NOTE since this is a trigger, which cannot be manually invoked, we insert a view record, which
      # is the trigger condition
      expect {
        ActiveRecord::Base.connection.execute <<-SQL
          CREATE MATERIALIZED VIEW baz AS
            SELECT 
              true  AS column_1
          ;
          CREATE VIEW bar AS
            SELECT 
              true  AS column_1,
              baz.column_1 AS column_2
            FROM baz
          ;
          CREATE MATERIALIZED VIEW foo AS
            SELECT 
              true  AS column_1,
              bar.column_1 AS column_2
            FROM bar
          ;
        SQL
      }.to change { Viewy::Models::ViewDependency.find_by(view_name: 'bar') }
        .from(nil)
        .to(instance_of(Viewy::Models::ViewDependency))
      .and change { Viewy::Models::MaterializedViewDependency.find_by(view_name: 'foo') }
        .from(nil)
        .to(instance_of(Viewy::Models::MaterializedViewDependency))
    end
  end
end
