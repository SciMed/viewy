require 'rails_helper'

describe Viewy::DependencyManagement::ViewSorter do

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
  let(:dependency_6) do
    instance_double 'Viewy::Models::MaterializedViewDependency',
      view_name: 'blam',
      view_dependencies: %w(baz),
      materialized_view: false
  end
  let(:all_materialized_dependencies) do
    [dependency_1, dependency_2, dependency_3, dependency_4, dependency_5]
  end
  let(:all_dependencies) do
    [dependency_1, dependency_2, dependency_3, dependency_4, dependency_5, dependency_6]
  end
  before do
    allow(Viewy::Models::MaterializedViewDependency).to receive(:all).and_return all_materialized_dependencies
    allow(Viewy::Models::ViewDependency).to receive(:all).and_return all_dependencies
  end

  describe '#sorted_views' do
    it 'yields the views in the expected order' do
      expect { |b| subject.sorted_views.each(&b) }.to yield_successive_args('baz', 'bar', 'foo', 'buzz', 'bang', 'blam')
    end
  end

  describe '#sorted_materialized_views' do
    it 'yields the views in the expected order' do
      expect { |b| subject.sorted_materialized_views.each(&b) }.to yield_successive_args('baz', 'bar', 'foo', 'buzz')
    end
  end
end
