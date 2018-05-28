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
      def refresh!(concurrently: false)
        refresher = Viewy::DependencyManagement::ViewRefresher.new(Viewy.connection)
        refresher.refresh_materialized_view(full_table_name, with_dependencies: true, concurrently: concurrently)
      end

      # Refreshes this view without refreshing any dependencies
      #
      # @raise [ActiveRecord::StatementInvalidError] raised if a dependent view is somehow not refreshed correctly
      #
      # @return [PG::Result] the result of the refresh statement on the materialized view
      def refresh_without_dependencies!(concurrently: false)
        refresher = Viewy::DependencyManagement::ViewRefresher.new(Viewy.connection)
        refresher.refresh_materialized_view(full_table_name, with_dependencies: false, concurrently: concurrently)
      end

      # Provides an array of sorted view dependencies
      #
      # @return [Array<String>]
      def sorted_view_dependencies
        view_dep = Viewy::Models::MaterializedViewDependency.find(full_table_name)
        Viewy::DependencyManagement::ViewSorter.new.sorted_materialized_view_subset(view_names: view_dep.view_dependencies)
      end

      # Determines if a view has been populated (i.e. is in a queryable state)
      #
      # @return [Boolean] true if the view has been populated, false if not
      def populated?
        query = <<-SQL
          SELECT ispopulated 
          FROM pg_matviews 
          WHERE matviewname = '#{table_name}' 
            AND schemaname = '#{schema_name.chomp('.')}';
        SQL
        result = connection.execute query
        ActiveRecord::Type::Boolean.new.cast(result.values[0][0])
      end

      private def full_table_name
        "#{schema_name}#{table_name}"
      end

      private def schema_name
        chunks = table_name.to_s.partition('.')
        if chunks[2].present?
          ''
        else
          "#{connection.current_schema}."
        end
      end
    end
  end
end
