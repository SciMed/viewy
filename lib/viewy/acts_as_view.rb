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
        view_dep = Viewy::Models::MaterializedViewDependency.find(table_name)
        view_dep.view_dependencies.each do |view_dependency|
          connection.execute("REFRESH MATERIALIZED VIEW #{view_dependency}")
        end
      end
    end
  end
end
