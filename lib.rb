# A hacky library to be required by LB6 rakefiles

verbose(false)

task :default => :update

desc "Copies shared js libraries to the actions that need them."
task :update => :clean do
  includes do |src, dest|
    unless ENV['DEBUG']
      mkdir_p(File.dirname(dest)) unless File.exists?(dest)
      cp_r src, dest
    end
  end
end

desc "Deletes all the shared js libraries in the actions"
task :clean do
  actions.each do |dir|
    dir = "#{dir}/shared"
    puts "==> Deleting #{dir}"
    rm_rf dir unless ENV['DEBUG']
  end
  puts ""
end

########################################

@DIRS = ["shared", "shared/lib"]

def actions(action_path = ".")
  Dir.glob("#{action_path}/{*.lbaction,*.lbext/Contents/Resources/Actions/*.lbaction}/Contents/Scripts")
end

def includes(path = ".")
  actions(path).each do |dir|
    puts "==> Checking #{dir.split(".lbaction").first}.lbaction"

    libs = []
    scripts(dir) do |script|
      libs.concat(requires(script))
    end
    libs.uniq!
    libs.delete("")
    libs.each do |lib|
      puts "  * #{lib} => #{dir}/#{lib}"
      yield lib, "#{dir}/#{lib}"
    end
  end
end

def scripts(action_dir)
  Dir.glob("#{action_dir}/**/*.js") { |script| yield script }
end

def getPath(file, relative = nil)
  return "#{relative}/#{file}" if relative and File.exists?("#{relative}/#{file}")

  @DIRS.each do |dir|
    return "#{dir}/#{file}" if File.exists?("#{dir}/#{file}")
  end
  raise "No path was found for #{file}"
end

# TODO: Make this... *not* ugly? ...Or don't
def requires(file)
  return [] unless File.exists?(file)

  relpath = file.split("/Contents/Scripts/")[1].sub("/$", "").split("/")

  libs = []
  File.read(file).scan(/include\(['"](.+)['"]\);/).each do |lib|
    ns = lib[0].split("/")
    qn = ns[1, ns.length-1].join("/")
    if ns[0] == "shared"
      libs.push(getPath(qn, file))
    elsif relpath[0] == "shared"
      # Find relative paths from inside shared libs
      lib = "#{relpath[0, relpath.length-1].join('/')}/#{ns.join('/')}"
      raise "No path was found for #{lib}" unless File.exists?(lib)
      libs.push(lib)
    end
  end
  return libs
end
