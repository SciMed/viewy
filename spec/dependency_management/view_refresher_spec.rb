require 'rails_helper'

describe Viewy::DependencyManagement::ViewRefresher do
  let(:dummy_connection) do
    double 'SomeConnection',
      execute: true
  end
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

  subject do
    described_class.new(dummy_connection)
  end

  describe '#refresh_materialized_view' do
    it 'refreshes the passed view name' do
      subject.refresh_materialized_view('foo')
      expect(dummy_connection).to have_received(:execute).with('REFRESH MATERIALIZED VIEW foo')
    end
    context 'concurrently' do
      it 'adds the `CONCURRENTLY` modifier to the refresh query' do
        subject.refresh_materialized_view('foo', concurrently: true)
        expect(dummy_connection).to have_received(:execute).with('REFRESH MATERIALIZED VIEW CONCURRENTLY foo')
      end
    end
    context 'with dependencies' do
      before do
        allow(Viewy::Models::MaterializedViewDependency).to receive(:find).with('foo').and_return(dependency_1)
        allow(Viewy::Models::MaterializedViewDependency).to receive(:where).with(view_name: %w(bar baz)).and_return([dependency_2, dependency_3])
      end
      it 'refreshes views with dependencies' do
        subject.refresh_materialized_view('foo', with_dependencies: true)
        expect(dummy_connection).to have_received(:execute).with('REFRESH MATERIALIZED VIEW baz').ordered
        expect(dummy_connection).to have_received(:execute).with('REFRESH MATERIALIZED VIEW bar').ordered
        expect(dummy_connection).to have_received(:execute).with('REFRESH MATERIALIZED VIEW foo').ordered
      end
    end
    context 'with dependencies concurrently' do
      before do
        allow(Viewy::Models::MaterializedViewDependency).to receive(:find).with('foo').and_return(dependency_1)
        allow(Viewy::Models::MaterializedViewDependency).to receive(:where).with(view_name: %w(bar baz)).and_return([dependency_2, dependency_3])
      end
      it 'refreshes views with dependencies' do
        subject.refresh_materialized_view('foo', with_dependencies: true, concurrently: true)
        expect(dummy_connection).to have_received(:execute).with('REFRESH MATERIALIZED VIEW CONCURRENTLY baz').ordered
        expect(dummy_connection).to have_received(:execute).with('REFRESH MATERIALIZED VIEW CONCURRENTLY bar').ordered
        expect(dummy_connection).to have_received(:execute).with('REFRESH MATERIALIZED VIEW CONCURRENTLY foo').ordered
      end
    end
  end

  describe '#refresh_all_materialized_views' do
    it 'refreshes the materialized views in the order in which they should be refreshed' do
      expected_order = %w(baz bar foo buzz)

      subject.refresh_all_materialized_views

      expected_order.each do |view_name|
        expect(dummy_connection).to have_received(:execute).with("REFRESH MATERIALIZED VIEW #{view_name}").ordered
      end
      expect(dummy_connection).not_to have_received(:execute).with('REFRESH MATERIALIZED VIEW bang')
    end
  end
end
