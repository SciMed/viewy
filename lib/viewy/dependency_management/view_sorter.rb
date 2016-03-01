module Viewy
  module DependencyManagement
    class ViewSorter
      include TSort

      private :tsort

      # @return [Array<String>] the ordered names of all views in the system in safe dependency order
      def sorted_views
        @views = generate_view_hash(Viewy::Models::ViewDependency.all)
        tsort
      end

      # @return [Array<String>] the ordered names of the materialized views in the system in safe dependency order
      def sorted_materialized_views
        @views = generate_materialized_view_hash(Viewy::Models::MaterializedViewDependency.all)
        tsort
      end

      # @return [Array<String>] the ordered names of the subset of views in the system in safe dependency order
      def sorted_view_subset(view_names:)
        @views = generate_view_hash(Viewy::Models::ViewDependency.where(view_name: view_names))
        tsort
      end

      # @return [Array<String>] the ordered names of the subset of materialized views in safe dependency order
      def sorted_materialized_view_subset(view_names:)
        @views = generate_materialized_view_hash(Viewy::Models::MaterializedViewDependency.where(view_name: view_names))
        tsort
      end

      # @return [Hash] a hash with materialized view names as keys and their dependencies as an array of names
      private def views
        @views
      end

      # @return [Hash] a hash with all view names as keys and their dependencies as an array of names
      private def generate_view_hash(view_collection)
        views = view_collection.map do |dep|
          [dep.view_name, dep.view_dependencies]
        end
        Hash[views]
      end

      # @return [Hash] a hash with materialized view names as keys and their dependencies as an array of names
      private def generate_materialized_view_hash(view_collection)
        views = view_collection.select(&:materialized_view).map do |dep|
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
    end
  end
end
