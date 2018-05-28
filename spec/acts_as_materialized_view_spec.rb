require 'rails_helper'

# NOTE: MainView is the class that implements ActsAsMaterializedView

describe MainView do
  describe '.populated?' do
    context 'view populated' do
      before do
        described_class.refresh!
      end
      it 'returns true' do
        expect(described_class.populated?).to be_truthy
      end
    end
    context 'view not populated' do
      before do
        ActiveRecord::Base.connection.execute <<-SQL
          REFRESH MATERIALIZED VIEW main_view WITH NO DATA;
        SQL
      end
      it 'returns false' do
        expect(described_class.populated?).to be_falsey
      end
    end
  end
end

class FooMatView < ActiveRecord::Base
  include Viewy::ActsAsMaterializedView

  self.table_name = 'foo.mat_view'
end

describe FooMatView do
  describe '.sorted_view_dependencies' do
    it 'returns the view dependencies' do
      expect(described_class.sorted_view_dependencies).to eql ['public.mat_view_1']
    end
  end
  describe '.refresh!' do
    it 'does not raise an error' do
      expect {
        described_class.refresh!
      }.not_to raise_error
    end
  end
end


