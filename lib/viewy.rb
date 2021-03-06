require 'viewy/engine'
require 'viewy/models'
require 'viewy/acts_as_view'
require 'viewy/acts_as_materialized_view'
require 'viewy/dependency_management'
require 'viewy/dependency_manager'
require 'viewy/event_triggers'

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
    view_refresher.refresh_materialized_view('materialized_view_dependencies')
    view_refresher.refresh_materialized_view('all_view_dependencies')
  end

  def self.with_delayed_dependency_updates
    connection.execute <<-SQL.squish!
      ALTER EVENT TRIGGER view_dependencies_update DISABLE;
    SQL

    yield

    connection.execute <<-SQL.squish!
      ALTER EVENT TRIGGER view_dependencies_update ENABLE ALWAYS;
    SQL
    Viewy.refresh_all_dependency_information
  end

  # @return [Array<String>] the ordered names of all views in the system in safe dependency order
  def self.view_names_in_dependency_order
    Viewy::DependencyManagement::ViewSorter.new.sorted_views
  end

  # @return [Array<String>] the ordered names of the materialized views in the system in safe dependency order
  def self.materialized_view_names_in_dependency_order
    Viewy::DependencyManagement::ViewSorter.new.sorted_materialized_views
  end

  # The connection used by viewy to manage views
  #
  # @return [ActiveRecord::ConnectionAdapters::PostgreSQLAdapter] An ActiveRecord connection
  #   to a Postgres Database
  def self.connection
    ActiveRecord::Base.connection
  end
end
