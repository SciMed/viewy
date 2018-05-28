class FooOtherView < ActiveRecord::Base
  include Viewy::ActsAsView

  self.table_name = 'foo.other_view'
end
