module Viewy
  module Models
    # Provides a means of accessing information about view dependencies from within a Rails app.
    # The foreign key of the dependency information table is the name of the view that a user needs
    # dependency information about.
    class MaterializedViewDependency < ActiveRecord::Base
      self.table_name = 'materialized_view_dependencies'
      self.primary_key = 'view_name'
    end
  end
end
