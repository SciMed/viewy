require 'tsort'

module Viewy
  module DependencyManagement
    # Provides a means of refreshing materialized views in the order in which they were created
    #
    # @!attribute connection [r]
    #   @return [ActiveRecord::ConnectionAdapters::PostgreSQLAdapter] the underlying Postgres connection
    class ViewRefresher
      include TSort

      attr_reader :connection

      alias_method :ordered_views, :tsort
      private :tsort, :ordered_views

      # @param connection [ActiveRecord::ConnectionAdapters::PostgreSQLAdapter] An ActiveRecord connection
      #   to a Postgres Database
      def initialize(connection)
        @connection = connection
      end

      # This method will refresh all materialized views in order of dependency
      def refresh_all_materialized_views
        ordered_views.each do |view_name|
          refresh_materialized_view(view_name)
        end
      end

      # Refreshes a single materialized view
      #
      # @param view_name [String] the name of a materialized view
      def refresh_materialized_view(view_name)
        connection.execute(refresh_sql(view_name))
      end

      # Note: this method memoizes the result of the first call
      #
      # @return [Hash] a hash with materialized view names as keys and their dependencies as an array of names
      private def views
        @views ||= generate_view_hash
      end

      # @return [Hash] a hash with materialized view names as keys and their dependencies as an array of names
      private def generate_view_hash
        views = Viewy::Models::MaterializedViewDependency.all.select(&:materialized_view).map do |dep|
          [dep.view_name, dep.view_dependencies]
        end
        Hash[views]
      end

      private def tsort_each_node
        views.each_key do |view|
          yield view
        end
      end

      # @param name [String] the name of a materialized view
      private def tsort_each_child(view, &block)
        views[view].each(&block)
      end

      # @param name [String] the name of a materialized view
      # @return [String] the SQL statement needed to refresh the passed view
      def refresh_sql(name)
        <<-SQL.strip
          REFRESH MATERIALIZED VIEW #{name}
        SQL
      end
    end
  end
end
