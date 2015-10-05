require 'pry'
require 'pg'

HOSTNAME = :localhost
DATABASE = :tododb

class Todo
  attr_accessor :id, :title, :content, :completed

  def initialize(args)
    @id = args[:id] if args.has_key? :id
    @title = args[:title] if args.has_key? :title
    @content = args[:content] if args.has_key? :content
    @completed = args[:completed] if args.has_key? :completed
    @id = args['id'] if args.has_key? 'id'
    @title = args['title'] if args.has_key? 'title'
    @content = args['content'] if args.has_key? 'content'
    @completed = args['completed'] if args.has_key? 'completed'
  end

  def self.connect
    @@c = PGconn.new(host: HOSTNAME, dbname: DATABASE)
  end

  def self.close
    @@c.close
  end

  def self.create(args)
    c = connect
    todo = Todo.new(args)
    todo.save
    c.close
  end

  def self.find(id)
    c = connect
    todo_data = c.exec_params("SELECT * FROM todos WHERE id = $1", [id])
    todo = Todo.new(id:  todo_data[0]['id'], title:  todo_data[0]['title'], content:  todo_data[0]['content'], completed:  todo_data[0]['completed'])
    c.close
    todo
  end

  def self.all
    c = connect
    results = []
    res = c.exec "SELECT * FROM todos;"

    res.each do |todo|
    results << Todo.new(todo)
    end

    c.close
    results.sort
  end

  def self.find_complete
    c = connect
    results = []

    res = c.exec "SELECT * FROM todos WHERE completed = true;"
    res.each do |todo|
      results << Todo.new(todo)
    end
    c.close
    results.sort
  end

  def self.list(options = {alert: nil, want_completed_list: false})
    if !options[:want_completed_list]
      todos = Todo.all
      title = "ALL TODOS:\n"
    else
      todos = Todo.find_complete
      title = "COMPLETED TODOS:\n"
    end


    counts = {id: 0, title: 0, content: 0}
    todos.each do |todo|
      if todo.id.to_s.size > counts[:id]
        counts[:id] = todo.id.size
      end
      if todo.title.size > counts[:title]
        counts[:title] = todo.title.size
      end
      if todo.content.size > counts[:content]
        counts[:content] = todo.content.size
      end
    end


    sum_for_dashes = (counts.values.reduce(:+) + 11) * 2

    if todos.size == 0
      sum_for_dashes = sum_for_dashes * 2
    end

    puts "\n"
    puts title
    puts "-" * sum_for_dashes
    if options[:alert] != nil
      puts options[:alert]
      puts "-" * sum_for_dashes
    end

    print "|id| ".ljust(counts[:id]  * 2)
    print "|title| ".ljust(counts[:title] * 2)
    print "|content| ".ljust(counts[:content] * 2)
    puts "|completed|".ljust(11)
    puts "-" * sum_for_dashes
    if todos.count > 0
      todos.each do |todo|
        puts "#{todo.id.ljust(counts[:id] * 2)} #{todo.title.ljust(counts[:title] * 2)} #{todo.content.ljust(counts[:content] * 2)} #{Todo.display_completed(todo.completed).ljust(11)}"
      end
    else
      if options[:want_completed_list]
        puts "\033[1;36m Nothing completed, get busy!!!\033[0m\n"
      else
        puts "\033[1;36m Nothing todo, lucky you!\033[0m\n"
      end
    end
    puts "-" * sum_for_dashes
  end

  def self.delete_all
    c = connect
    c.exec("DELETE FROM todos;")
    c.close
  end

  def self.display_completed(boolean)
    c_or_i = ""
    if boolean != "f"
      c_or_i = "☑"
    else
      c_or_i = "☐"
    end
    c_or_i
  end

  def save
    c = Todo.connect
    args = [title, content, completed]

    if id.nil?
      sql = "INSERT INTO todos (title, content, completed) VALUES ($1, $2, $3)"
    else
      sql = "UPDATE todos SET title = $1, content = $2, completed = $3 WHERE id = $4"
      args.push id
    end
    sql += ' RETURNING *;'

    res = c.exec_params(sql, args)
    @id = res[0]['id']

    self
    c.close
  end

  def delete
    c = Todo.connect
    movie = c.exec_params("DELETE FROM todos WHERE id = $1", [self.id])
    c.close
  end

  def to_s
    "#{@id}: #{@title} - #{@content} - #{@completed}"
  end

  def <=>(other)
    self.id <=> other.id
  end
end


puts "\033[36m Welcome to the todo app, what would you like to do?\033[0m\n"
Todo.list
while true
  puts "n - make a new todo"
  puts "l - list all todos"
  puts "lc - list complete todos"
  puts "u [id] - update a todo with a given id"
  puts "c [id] - mark todo as complete"
  puts "d [id] - delete a todo with a given id (\033[1;31m if no id is provided, all todos will be deleted\033[0m )\n"
  puts "q - quit the application"

  userResponse = gets.chomp
  userResponse = userResponse.split

  case userResponse[0]
  when 'n'
    puts "Add title: "
    title = gets.chomp
    puts "Add content: "
    content = gets.chomp
    completed = false
    todo = {title: title, content: content, completed: completed}
    Todo.create(todo)
    Todo.list
  when 'l'
    Todo.list
  when 'lc'
    todos = Todo.find_complete
    Todo.list(want_completed_list: true)
  when 'u'
    if userResponse[1]
      puts "Add new title: "
      title = gets.chomp
      puts "Add new content: "
      content = gets.chomp
      completed = false
      todo = Todo.find(userResponse[1])
      todo.title = title
      todo.content = content
      todo.save
      Todo.list
    else
      Todo.list(alert: "NOTICE: \033[1;31m id required to update. try again.\033[0m\n")
    end
  when 'c'
    if userResponse[1]
      todo = Todo.find(userResponse[1])
      todo.completed = true
      todo.save
      Todo.list
    else
      Todo.list(alert: "NOTICE: \033[1;31m id required to mark as complete. try again.\033[0m\n")
    end
  when 'd'
    if userResponse[1]
      todo = Todo.find(userResponse[1])
      todo.delete
      Todo.list
    else
      Todo.delete_all
      Todo.list
    end
  when 'q'
    break
  else
    "Cannot compute..."
  end
end
