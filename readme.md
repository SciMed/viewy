#Viewy

##NOTE this is only for use with postgres 9.4 or higher.  

In a nutshell, it provides two separate functionalities:

1) It allows you to manage updates to a stack of views without having to manually delete and recreate the whole stack of views.  For instance if you have Views A, B, C, D with A -> B, C and C->D and you need to update how view D gets a column, you can do
```
view_manager = Viewy::DependencyManager.new
view_manager.replace_view(
  'd',
   <<-SQL
     SELECT * FROM ... 
   SQL
)
```
Which will automatically remove everything above D in the dependency hierarchy, replace D with the new view sql, and then recreate the views above it

2)  It provides some methods specific to managing ActiveRecord models that are backed by materialized views through `Viewy::ActsAsMaterializedView`. Most importantly it refreshes materialized views in order of their dependencies.  For instance, in the hierarchy I described, if A, and C are materialized views then calling `A.refresh!` will refresh view C and then view A.

This project rocks and uses MIT-LICENSE.
