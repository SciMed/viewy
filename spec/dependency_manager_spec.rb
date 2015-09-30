require 'rails_helper'

describe Viewy::DependencyManager do
  let(:dummy_connection) do
    double 'SomeConnection',
      execute: true
  end

  before do
    allow_any_instance_of(described_class).to receive(:connection).and_return(dummy_connection)
  end

  describe 'initialization' do
    it 'refreshes the materialized_view_dependencies view' do
      described_class.new
      expect(dummy_connection).to have_received(:execute)
          .with('REFRESH MATERIALIZED VIEW materialized_view_dependencies')
    end
  end

  describe '#refresh_all_materialized_views' do
    let(:dependency_1) do
      instance_double 'Viewy::Models::MaterializedViewDependency',
        view_name: 'foo',
        view_dependencies: %w(bar baz),
        materialized_view: true
    end
    let(:dependency_2) do
      instance_double 'Viewy::Models::MaterializedViewDependency',
        view_name: 'bar',
        view_dependencies: %w(baz),
        materialized_view: true
    end
    let(:dependency_3) do
      instance_double 'Viewy::Models::MaterializedViewDependency',
        view_name: 'baz',
        view_dependencies: [],
        materialized_view: true
    end
    let(:dependency_4) do
      instance_double 'Viewy::Models::MaterializedViewDependency',
        view_name: 'buzz',
        view_dependencies: [],
        materialized_view: true
    end
    let(:dependency_5) do
      instance_double 'Viewy::Models::MaterializedViewDependency',
        view_name: 'bang',
        view_dependencies: %w(bar baz),
        materialized_view: false
    end
    let(:all_dependencies) do
      [dependency_1, dependency_2, dependency_3, dependency_4, dependency_5]
    end
    before do
      allow(Viewy::Models::MaterializedViewDependency).to receive(:all).and_return all_dependencies
    end
    it 'returns the names of the materialized views in the order in which they should be refreshed' do
      expected_order = %w(baz bar foo buzz)

      subject.refresh_all_materialized_views

      expect(dummy_connection).to have_received(:execute)
          .with('REFRESH MATERIALIZED VIEW materialized_view_dependencies').ordered

      expected_order.each do |view_name|
        expect(dummy_connection).to have_received(:execute).with("REFRESH MATERIALIZED VIEW #{view_name}").ordered
      end
      expect(dummy_connection).not_to have_received(:execute).with('REFRESH MATERIALIZED VIEW bang')
    end
  end
end
