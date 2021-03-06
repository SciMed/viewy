require 'rails_helper'

describe Viewy::DependencyManager do
  let(:dummy_connection) do
    double 'SomeConnection',
      execute: true
  end

  before do
    allow(Viewy).to receive(:connection).and_return(dummy_connection)
  end

  describe '#replace_view' do
    let(:dummy_model) do
      double 'SomeMaterializedViewModel',
        refresh!: true
    end
    it 'uses the replace_view SQL function to replace the passed view name with teh provided view SQL' do
      subject.replace_view('foo', 'SELECT * FROM bar')
      expect(dummy_connection).to have_received(:execute).with("SELECT replace_view('foo', $$SELECT * FROM bar$$)")
    end
    it 'accepts a post-replace callback block' do
      subject.replace_view('foo', 'SELECT * FROM bar') do
        dummy_model.refresh!
      end
      expect(dummy_model).to have_received(:refresh!)
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
      allow(Viewy).to receive(:refresh_materialized_dependency_information)
    end
    it 'refreshes the materialized view dependency information' do
      subject.refresh_all_materialized_views
      expect(Viewy).to have_received(:refresh_materialized_dependency_information)
    end
    it 'returns the names of the materialized views in the order in which they should be refreshed' do
      expected_order = %w(baz bar foo buzz)

      subject.refresh_all_materialized_views

      expected_order.each do |view_name|
        expect(dummy_connection).to have_received(:execute).with("REFRESH MATERIALIZED VIEW #{view_name}").ordered
      end
      expect(dummy_connection).not_to have_received(:execute).with('REFRESH MATERIALIZED VIEW bang')
    end
  end
end
