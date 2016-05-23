require 'tsort'

module Viewy
  module DependencyManagement
    # Provides a means of refreshing materialized views in the order in which they were created
    #
    # @!attribute connection [r]
    #   @return [ActiveRecord::ConnectionAdapters::PostgreSQLAdapter] the underlying Postgres connection
    class ViewRefresher
      attr_reader :connection

      # @param connection [ActiveRecord::ConnectionAdapters::PostgreSQLAdapter] An ActiveRecord connection
      #   to a Postgres Database
      def initialize(connection)
        @connection = connection
        @sorter = Viewy::DependencyManagement::ViewSorter.new
      end

      # This method will refresh all materialized views in order of dependency
      def refresh_all_materialized_views
        @sorter.sorted_materialized_views.each do |view_name|
          refresh_single_view(view_name, concurrently: false)
        end
      end

      # Refreshes a single materialized view
      #
      # @param view_name [String] the name of a materialized view
      def refresh_materialized_view(view_name, with_dependencies: false, concurrently: false)
        if with_dependencies
          refresh_dependent_views(view_name, concurrently: concurrently)
        end
        refresh_single_view(view_name, concurrently: concurrently)
      end

      private def refresh_dependent_views(view_name, concurrently:)
        view_dep = Viewy::Models::MaterializedViewDependency.find(view_name)
        dependencies = @sorter.sorted_materialized_view_subset(view_names: view_dep.view_dependencies)
        dependencies.each do |view_dependency|
          refresh_single_view(view_dependency, concurrently: concurrently)
        end
      end

      private def refresh_single_view(view_name, concurrently:)
        begin
          connection.execute(refresh_sql(view_name, concurrently))
        rescue ActiveRecord::StatementInvalid => ex
          if attempt_non_concurrent_refresh?(ex, concurrently)
            connection.execute(refresh_sql(view_name, false))
          end
        end
      end

      # @param ex [ActiveRecord::StatementInvalid] an exception raised during the view refresh
      # @param concurrently [Boolean] whether or not the refresh that raised the exception was concurrent
      #
      # @raise [ActiveRecord::StatementInvalid] re-raised if the original exception does not indicate the refresh
      #   should be retried non-concurrently
      #
      # @return [Boolean] true if the system should attempt to refresh the view non-concurrently after a concurrent
      #   refresh has failed.  Since Postgres raises an error when an unpopulated view is refreshed concurrently, this
      #   allows the system to populated such views if needed
      private def attempt_non_concurrent_refresh?(ex, concurrently)
        original_exception = ex.original_exception
        should_retry_non_concurrently = original_exception.instance_of?(PG::FeatureNotSupported) ||
          original_exception.instance_of?(PG::ObjectNotInPrerequisiteState)

        if should_retry_non_concurrently
          concurrently
        else
          raise ex
        end
      end

      # @param name [String] the name of a materialized view
      # @return [String] the SQL statement needed to refresh the passed view
      private def refresh_sql(name, concurrently)
        return concurrent_refersh_sql(name) if concurrently
        <<-SQL.strip
          REFRESH MATERIALIZED VIEW #{name}
        SQL
      end

      private def concurrent_refersh_sql(name)
        <<-SQL.strip
          REFRESH MATERIALIZED VIEW CONCURRENTLY #{name}
        SQL
      end
    end
  end
end
