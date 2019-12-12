# frozen_string_literal: true

require "sinatra"
require "sinatra/reloader"
use Rack::MethodOverride

class Memo
  FILE_DIRECTORY = "./memos/"
  BACKUP_DIRECTORY = "./memos_backup/"
  BACKUP_SUFFIX = ".bak"
  attr_reader :file_id, :file_path

  def initialize(id)
    @file_id = id
    @file_path = FILE_DIRECTORY + @file_id
    @backup_path = BACKUP_DIRECTORY + @file_id + BACKUP_SUFFIX
  end

  def first_line
    File.open(@file_path, "r").gets
  end

  def all_lines
    File.open(@file_path, "r").read
  end

  def save(content)
    File.open(@file_path, "w") { |f| f.write(content) }
  end

  def mtime
    File.mtime(@file_path)
  end

  def exist?
    File.exist?(@file_path)
  end

  def delete
    backup
    File.delete(@file_path) if File.exist?(@file_path)
  end

  def patch(content)
    backup
    save(content)
  end

  private
    def backup
      File.open(@backup_path, "w") { |f| f.write(all_lines) }
    end
end

class MemoList
  def initialize(ids)
    @memos = ids.map { |id| Memo.new(id) }
  end

  def sort!
    @memos.sort_by! { |memo| memo.mtime }.reverse!
  end

  def first_lines
    @memos.map { |memo| memo.first_line }
  end

  def file_ids
    @memos.map { |memo| memo.file_id }
  end
end

get "/memos" do
  ml = MemoList.new(Dir.glob("*", base: Memo::FILE_DIRECTORY))
  ml.sort!
  @contents = ml.first_lines.zip(ml.file_ids)
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
  if params[:memo].match?(/\A\R|\A\Z/)
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
