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
          refresh_materialized_view(view_name)
        end
      end

      # Refreshes a single materialized view
      #
      # @param view_name [String] the name of a materialized view
      def refresh_materialized_view(view_name)
        connection.execute(refresh_sql(view_name))
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
