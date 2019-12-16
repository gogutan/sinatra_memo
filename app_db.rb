# frozen_string_literal: true

require "sinatra"
require "sinatra/reloader"
require "pg"
use Rack::MethodOverride

class Memo
  MEMO_TABLE = "memo"
  BACKUP_TABLE = "memo_backup"

  def initialize(id)
    @connection = PG.connect(host: "localhost", user: "postgres", password: "", dbname: "memodb", port: "5432")
    @memo_id = id
  end

  def all_lines
    @connection.exec("SELECT * FROM #{MEMO_TABLE} WHERE memo_id = $1", [@memo_id])[0]["memo_content"]
  end

  def save(content)
    @connection.exec("INSERT INTO #{MEMO_TABLE}(memo_id, memo_content, updated_at) VALUES ($1, $2, $3)", [@memo_id, content, Time.now])
  end

  def mtime
    @connection.exec("SELECT * FROM #{MEMO_TABLE} WHERE memo_id = $1", [@memo_id])[0]["updated_at"]
  end

  def exist?
    @connection.exec("SELECT EXISTS (SELECT * FROM #{MEMO_TABLE} WHERE memo_id = $1)", [@memo_id])[0]["exists"] == "t" ? true : false
  end

  def delete
    backup
    @connection.exec("DELETE FROM #{MEMO_TABLE} WHERE memo_id = $1", [@memo_id])
  end

  def patch(content)
    backup
    update(content)
  end

  private
    def backup
      if backup_exists?
        @connection.exec("UPDATE #{BACKUP_TABLE} SET memo_content = $1, updated_at = $2 WHERE memo_id = $3", [all_lines, Time.now, @memo_id])
      else
        @connection.exec("INSERT INTO #{BACKUP_TABLE}(memo_id, memo_content, updated_at) VALUES ($1, $2, $3)", [@memo_id, all_lines, Time.now])
      end
    end

    def backup_exists?
      @connection.exec("SELECT EXISTS (SELECT * FROM #{BACKUP_TABLE} WHERE memo_id = $1)", [@memo_id])[0]["exists"] == "t" ? true : false
    end

    def update(content)
      @connection.exec("UPDATE #{MEMO_TABLE} SET memo_content = $1, updated_at = $2 WHERE memo_id = $3", [content, Time.now, @memo_id])
    end
end

class MemoList
  def initialize
    @connection = PG.connect(host: "localhost", user: "postgres", password: "", dbname: "memodb", port: "5432")
    @memos = @connection.exec("SELECT * FROM #{Memo::MEMO_TABLE}").to_a
  end

  def sort!
    @memos.sort_by! { |tuple| tuple["updated_at"] }.reverse!
  end

  def first_lines
    @memos.map { |tuple| tuple["memo_content"].lines[0] }
  end

  def memo_ids
    @memos.map { |tuple| tuple["memo_id"] }
  end
end

get "/memos" do
  ml = MemoList.new
  ml.sort!
  @contents = ml.first_lines.zip(ml.memo_ids)
  erb :"memos/index"
end

post "/memos" do
  if params[:memo].match?(/\A\R|\A\z/)
    @caution = "1行目が空のメモは保存できません。"
    @all_lines = "\r\n" + params[:memo]
    erb :"memos/new"
  else
    memo = Memo.new(SecureRandom.uuid)
    memo.save(params[:memo])
    redirect "/memos"
  end
end

get "/memos/new" do
  erb :"memos/new"
end

get "/memos/:id/edit" do |id|
  @id = id
  memo = Memo.new(id)
  if memo.exist?
    @all_lines = "\r\n" + memo.all_lines
    erb :"memos/edit"
  else
    erb :"memos/404"
  end
end

get "/memos/:id" do |id|
  @id = id
  memo = Memo.new(id)
  if memo.exist?
    @all_lines = "\r\n" + memo.all_lines
    erb :"memos/show"
  else
    erb :"/memos/404"
  end
end

delete "/memos/:id" do |id|
  memo = Memo.new(id)
  memo.delete
  redirect "/memos"
end

patch "/memos/:id" do |id|
  memo = Memo.new(id)
  if params[:memo].match?(/\A\R|\A\z/)
    @caution = "1行目が空のメモは保存できません。"
    if memo.exist?
      @id = id
      @all_lines = "\r\n" + params[:memo]
      erb :"memos/edit"
    else
      erb :"memos/404"
    end
  else
    memo.patch(params[:memo])
    redirect "/memos"
  end
end
