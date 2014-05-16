
module AutoLoad

  def testing_dir? full_name
    return_val = false
    ["test/","spec/","vendor/bundle/","bootstrap.rb","autoload.rb"].each{|f| return_val = true if full_name.include?(f)  }
    return_val
  end
     
  def load
    # preload all files.
    Dir.glob('*.rb').reject{|file| testing_dir?(file) }.each{|file| puts file; require "./#{file}" }
    Dir.glob('**/*.rb').reject{|file| testing_dir?(file) }.each{|file| puts file; require "./#{file}" }
  end

end
