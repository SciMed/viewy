module Viewy
  # Provides a wrapper for SQL views that allows them and their materialized dependencies to be refreshed easily
  module ActsAsView
    extend ActiveSupport::Concern

    class_methods do
      # Refreshes this view and all materialized views it depends on.
      # NOTE: the look-up for dependencies can take a second to run.
      #
      # @raise [ActiveRecord::RecordNotFoundError] raised when the view #refresh! is called on does not exist
      # @raise [ActiveRecord::StatementInvalidError] raised if a dependent view is somehow not refreshed correctly
      #
      # @return [nil]
      def refresh!
        view_dep = Viewy::Models::ViewDependency.find(table_name)
        deps = Viewy::DependencyManagement::ViewSorter.new.sorted_view_subset(view_names: view_dep.view_dependencies)
        deps.each do |view_dependency|
          materialized_view_dependency = Viewy::Models::MaterializedViewDependency.find_by(view_name: view_dependency)
          ActiveRecord::Base.connection.execute("REFRESH MATERIALIZED VIEW #{view_dependency}") if materialized_view_dependency
        end
      end
    end
  end
end
