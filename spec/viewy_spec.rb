require 'spec_helper'

describe Viewy do
  describe '.refresh_materialized_dependency_information' do
    let(:dummy_connection) do
      double 'SomeConnection',
        execute: true
    end

    before do
      allow(described_class).to receive(:connection).and_return(dummy_connection)
    end
    it 'refreshes the materialized_view_dependencies view' do
      described_class.refresh_materialized_dependency_information
      expect(dummy_connection).to have_received(:execute)
          .with('REFRESH MATERIALIZED VIEW materialized_view_dependencies')
    end
  end

  describe '.with_delayed_dependency_updates' do
    let(:dummy_connection) do
      double 'SomeConnection',
        execute: true
    end

    before do
      allow(described_class).to receive(:connection).and_return(dummy_connection)
      allow(Viewy).to receive(:refresh_all_dependency_information)
    end

    it 'disables dependency updating before yielding' do
      described_class.with_delayed_dependency_updates do
        dummy_connection.execute("SOME SQL")
      end
      expect(dummy_connection).to have_received(:execute)
        .with('ALTER EVENT TRIGGER view_dependencies_update DISABLE;')
        .ordered
      expect(dummy_connection).to have_received(:execute)
        .with('SOME SQL')
        .ordered
    end

    it 'enables dependency updating after yielding' do
      described_class.with_delayed_dependency_updates do
        dummy_connection.execute("SOME SQL")
      end
      expect(dummy_connection).to have_received(:execute)
        .with('SOME SQL')
        .ordered
      expect(dummy_connection).to have_received(:execute)
        .with('ALTER EVENT TRIGGER view_dependencies_update ENABLE ALWAYS;')
        .ordered
    end

    it 'refreshes dependency info after enabling dependency updating' do
      described_class.with_delayed_dependency_updates do
        dummy_connection.execute("SOME SQL")
      end
      expect(dummy_connection).to have_received(:execute)
        .with('ALTER EVENT TRIGGER view_dependencies_update ENABLE ALWAYS;')
        .ordered
      expect(Viewy).to have_received(:refresh_all_dependency_information)
    end
  end

  describe '.refresh_all_dependency_information' do
    let(:dummy_connection) do
      double 'SomeConnection',
        execute: true
    end

    before do
      allow(described_class).to receive(:connection).and_return(dummy_connection)
    end
    it 'refreshes the materialized_view_dependencies view' do
      described_class.refresh_all_dependency_information
      expect(dummy_connection).to have_received(:execute)
          .with('REFRESH MATERIALIZED VIEW materialized_view_dependencies').ordered
      expect(dummy_connection).to have_received(:execute)
          .with('REFRESH MATERIALIZED VIEW all_view_dependencies').ordered
    end
  end
  describe '.connection' do
    it 'returns the active record base connection' do
      expect(described_class.connection).to eql ActiveRecord::Base.connection
    end
  end
end
