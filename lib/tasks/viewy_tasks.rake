namespace :viewy do
  desc 'This task updates the dependency information view'
  task :refresh_dependency_information, :environment do
    puts 'Refreshing view dependency information cache...'
    Viewy.refresh_all_dependency_information
    puts 'View dependency information refresh complete.'
  end

  task :include_triggers_in_structure, :environment do
    version_sql = <<-SQL
      SHOW server_version;
    SQL
    result = Viewy.connection.execute(version_sql)
    unless result.values[0][0].match(/9\.4/)
      puts 'Updating structure.sql to include event triggers'
      path = File.expand_path('db/structure.sql', Rails.root)
      File.open(path, 'a') do |structure_sql|
        event_triggers = Viewy::EventTriggers.new
        structure_sql.puts
        structure_sql.puts event_triggers.event_triggers_sql
      end
    end
  end
end

Rake::Task['db:structure:dump'].enhance do
  if Rake::Task.task_defined?('viewy:include_triggers_in_structure')
    Rake::Task['viewy:include_triggers_in_structure'].invoke
  else
    Rake::Task['app:viewy:include_triggers_in_structure'].invoke
  end
end
