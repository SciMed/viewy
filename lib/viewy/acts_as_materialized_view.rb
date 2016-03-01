module Viewy
  # Provides a wrapper for materialized views that allows them and their dependencies to be refreshed easily
  module ActsAsMaterializedView
    extend ActiveSupport::Concern

    class_methods do
      # Refreshes this view and all materialized views it depends on.
      # NOTE: the look-up for dependencies can take a second to run.
      #
      # @raise [ActiveRecord::RecordNotFoundError] raised when the view #refresh! is called on does not exist
      # @raise [ActiveRecord::StatementInvalidError] raised if a dependent view is somehow not refreshed correctly
      #
      # @return [PG::Result] the result of the refresh statement on the materialized view
      def refresh!
        sorted_view_dependencies.each do |view_dependency|
          ActiveRecord::Base.connection.execute("REFRESH MATERIALIZED VIEW #{view_dependency}")
        end
        refresh_without_dependencies!
      end

      # Refreshes this view without refreshing any dependencies
      #
      # @raise [ActiveRecord::StatementInvalidError] raised if a dependent view is somehow not refreshed correctly
      #
      # @return [PG::Result] the result of the refresh statement on the materialized view
      def refresh_without_dependencies!
        ActiveRecord::Base.connection.execute("REFRESH MATERIALIZED VIEW #{table_name}")
      end

      # Provides an array of sorted view depenedencies
      #
      # @return [Array<String>]
      def sorted_view_dependencies
        view_dep = Viewy::Models::MaterializedViewDependency.find(table_name)
        Viewy::DependencyManagement::ViewSorter.new.sorted_materialized_view_subset(view_names: view_dep.view_dependencies)
      end
    end
  end
end
