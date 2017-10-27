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
