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

  describe '#sorted_view_subset' do
    let(:some_dependencies) do
      [dependency_1, dependency_3, dependency_6, dependency_2]
    end

    before do
      allow(Viewy::Models::ViewDependency).to receive(:where).and_return(some_dependencies)
    end

    it 'sorts the set of views' do
      name_param = %w(bar foo blam baz)
      expect(subject.sorted_view_subset(view_names: name_param)).to eql %w(baz bar foo blam)
      expect(Viewy::Models::ViewDependency).to have_received(:where).with(view_name: name_param)
    end
  end

  describe '#sorted_materialized_view_subset' do
    let(:some_dependencies) do
      [dependency_1, dependency_3, dependency_2]
    end

    before do
      allow(Viewy::Models::MaterializedViewDependency).to receive(:where).and_return(some_dependencies)
    end

    it 'sorts the set of views' do
      name_param = %w(bar foo baz)
      expect(subject.sorted_materialized_view_subset(view_names: name_param)).to eql %w(baz bar foo)
      expect(Viewy::Models::MaterializedViewDependency).to have_received(:where).with(view_name: name_param)
    end
  end
end
