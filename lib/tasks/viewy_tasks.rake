namespace :viewy do
  desc 'This task updates the dependency information view'
  task :refresh_dependency_information, :environment do
    puts 'Refreshing view dependency information cache...'
    Viewy.refresh_dependency_information
    puts 'View dependency information refresh complete.'
  end
end
