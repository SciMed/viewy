require 'viewy/engine'
require 'viewy/models'
require 'viewy/acts_as_view'
require 'viewy/acts_as_materialized_view'
require 'viewy/dependency_management'
require 'viewy/dependency_manager'

# Viewy provides a means of interacting with views in a Postgres database in a way that allows the manipulation
# of views and their dependencies
module Viewy
  # Calling this method will refresh the materialized view that stores the dependency information for other
  # materialized views in the system
  #
  # @raise [ActiveRecord::StatementInvalidError] raised if a dependent view is somehow not refreshed correctly
  # @return [PG::Result] the result of the refresh statement on the materialized view
  def self.refresh_materialized_dependency_information
    view_refresher = Viewy::DependencyManagement::ViewRefresher.new(connection)
    view_refresher.refresh_materialized_view('materialized_view_dependencies')
  end

  # Calling this method will refresh the materialized view that stores the dependency information for other
  # views in the system
  #
  # @raise [ActiveRecord::StatementInvalidError] raised if a dependent view is somehow not refreshed correctly
  # @return [PG::Result] the result of the refresh statement on the materialized view
  def self.refresh_all_dependency_information
    view_refresher = Viewy::DependencyManagement::ViewRefresher.new(connection)
    view_refresher.refresh_materialized_view('all_view_dependencies')
  end

  # The connection used by viewy to manage views
  #
  # @return [ActiveRecord::ConnectionAdapters::PostgreSQLAdapter] An ActiveRecord connection
  #   to a Postgres Database
  def self.connection
    ActiveRecord::Base.connection
  end
end
