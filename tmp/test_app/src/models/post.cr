class Post < Granite::Base
  adapter sqlite
  table_name posts

  # id : Int64 primary key is created for you
end
