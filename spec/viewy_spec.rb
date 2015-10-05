require 'spec_helper'

describe Viewy do
  describe '.refresh_dependency_information' do
    let(:dummy_connection) do
      double 'SomeConnection',
        execute: true
    end

    before do
      allow(described_class).to receive(:connection).and_return(dummy_connection)
    end
    it 'refreshes the materialized_view_dependencies view' do
      described_class.refresh_dependency_information
      expect(dummy_connection).to have_received(:execute)
          .with('REFRESH MATERIALIZED VIEW materialized_view_dependencies')
    end
  end
  describe '.connection' do
    it 'returns the active record base connection' do
      expect(described_class.connection).to eql ActiveRecord::Base.connection
    end
  end
end
