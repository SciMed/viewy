class MainView < ActiveRecord::Base
  include Viewy::ActsAsMaterializedView

  self.table_name = 'main_view'
end
