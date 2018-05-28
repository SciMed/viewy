require 'rails_helper'

describe FooOtherView do
  describe 'refresh!' do
    before do
      Viewy.refresh_all_dependency_information
    end

    it 'does not raise an error' do
      expect {
        described_class.refresh!
      }.not_to raise_error
    end
  end
end
