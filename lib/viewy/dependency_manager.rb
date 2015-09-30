module Viewy
  # Provides an interface for managing the dependencies of views within the application.
  #
  # NOTE: the dependencies view is refreshed when an instance is initialized and this can take a little while to run.
  class DependencyManager
    # @param connection [ActiveRecord::ConnectionAdapters::PostgreSQLAdapter] An ActiveRecord connection
    #   to a Postgres Database
    def initialize
      view_refresher.refresh_materialized_view('materialized_view_dependencies')
    end

    # This method will refresh all materialized views in order of dependency
    #
    # @raise [ActiveRecord::StatementInvalidError] raised if a view is somehow not refreshed correctly
    def refresh_all_materialized_views
      view_refresher.refresh_all_materialized_views
    end

    # Replaces the named view (or materialized view) with the new definition SQL.
    # This will do the following
    #
    #   1. drop all view which depend on the view being replaced
    #   2. drop the view being replaced
    #   3. recreate the view with the passed sql
    #   4. re-create all of the views which depended on the replaced view
    #
    # NOTE: this is provided as a convenience for managing dependencies, and the user should not expect that the
    # re-created views will function if they rely on parts of the replaced view that are removed.
    #
    # @param view_name [String] the name of the view being replaced
    # @param new_definition_sql [String] the SQL definition of the new view
    #
    # @raise [ActiveRecord::StatementInvalidError] raised if a dependent view is somehow not refreshed correctly
    # @return [PG::Result] the result of the refresh statement on the materialized view
    def replace_view(view_name, new_definition_sql)
      connection.execute("SELECT replace_view('#{view_name}', $$#{new_definition_sql}$$)")
    end

    # @return [Viewy::DependencyManagement::ViewRefresher] a memoized view refresher object
    private def view_refresher
      @view_refresher ||= Viewy::DependencyManagement::ViewRefresher.new(connection)
    end

    # @return [ActiveRecord::ConnectionAdapters::PostgreSQLAdapter] An ActiveRecord connection
    #   to a Postgres Database
    private def connection
      ActiveRecord::Base.connection
    end
  end
end
