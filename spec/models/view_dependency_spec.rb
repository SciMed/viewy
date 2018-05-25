require 'rails_helper'

describe Viewy::Models::ViewDependency do
  describe 'columns' do
    it { is_expected.to have_db_column(:view_name).of_type(:text) }
    it { is_expected.to have_db_column(:materialized_view).of_type(:boolean) }
    it { is_expected.to have_db_column(:view_dependencies) }
  end
end
