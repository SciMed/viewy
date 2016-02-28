module Viewy
  module DependencyManagement
    class ViewSorter
      include TSort

      private :tsort

      # @return [Array<String>] the ordered names of all views in the system in safe dependency order
      def sorted_views
        @views = generate_view_hash
        tsort
      end

      # @return [Array<String>] the ordered names of the materialized views in the system in safe dependency order
      def sorted_materialized_views
        @views = generate_materialized_view_hash
        tsort
      end

      # @return [Hash] a hash with materialized view names as keys and their dependencies as an array of names
      private def views
        @views
      end

      # @return [Hash] a hash with all view names as keys and their dependencies as an array of names
      private def generate_view_hash
        views = Viewy::Models::ViewDependency.all.map do |dep|
          [dep.view_name, dep.view_dependencies]
        end
        Hash[views]
      end

      # @return [Hash] a hash with materialized view names as keys and their dependencies as an array of names
      private def generate_materialized_view_hash
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
    end
  end
end
