module Viewy
  # This provides a handle for dealing with Viewy specific event triggers, which are no longer exported from Postgres as of 9.5.1
  # See http://www.postgresql.org/message-id/8795.1452631064@sss.pgh.pa.us for more information
  #
  # NOTE: this should be updated any time a migration changes the triggers
  class EventTriggers
    # @return [String] the sql needed to create the view triggers needed for viewy to function
    def event_triggers_sql
      <<-SQL
        CREATE EVENT TRIGGER view_dependencies_update
        ON DDL_COMMAND_END
        WHEN TAG IN ('DROP VIEW', 'DROP MATERIALIZED VIEW', 'CREATE VIEW', 'CREATE MATERIALIZED VIEW', 'ALTER VIEW', 'ALTER MATERIALIZED VIEW')
        EXECUTE PROCEDURE refresh_materialized_view_dependencies();
      SQL
    end
  end
end
