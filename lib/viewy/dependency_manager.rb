require 'tsort'

module Viewy
  class DependencyManager
    include TSort

    def initialize
      connection.execute(refresh_sql('materialized_view_dependencies'))
    end

    def connection
      ActiveRecord::Base.connection
    end

    def refresh_all_materialized_views
      ordered_views.each do |view_name|
        connection.execute(refresh_sql(view_name))
      end
    end

    private def views
      @views ||= generate_view_hash
    end

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

    private def tsort_each_child(view, &block)
      views[view].each(&block)
    end

    private def refresh_sql(name)
      <<-SQL.strip
        REFRESH MATERIALIZED VIEW #{name}
      SQL
    end

    alias_method :ordered_views, :tsort
  end
end
