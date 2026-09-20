# this script assumes a flatpak install of prism

require "pathname"

Instance = Struct.new(:folder, :name) # make each instance entry an object in order to cleanly contain its folder and display name

def prism_find_launch
  instances = []
  configs = []

  configs += Pathname("~/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances").expand_path.glob("*/instance.cfg")
  configs += Pathname("~/.local/share/PrismLauncher/instances").expand_path.glob("*/instance.cfg")

# look at every instance config file in the prism directory, read the "name" of every one and list it
  configs.each do |config|
    folder = config.dirname.basename.to_s
    name = config.read[/^name=(.+)$/, 1]
    name = folder if name.nil?
    instances << Instance.new(folder, name.strip)
  end

  instances.each_with_index do |instance, index|
    puts "#{index + 1}. #{instance.name}"
  end

  print "Pick an instance: "

  if (number = gets.strip.to_i).between?(1, instances.length)
    instance = instances[number - 1]
    Thread.new do
      puts
      puts "Launching #{instance.name}..."
      system("flatpak", "run", "org.prismlauncher.PrismLauncher", "--launch", instance.folder, out: File::NULL, err: File::NULL) # silence output
    end

    until (window = `wmctrl -l`.downcase.lines.find {|line| line.include?("minecraft")})
      sleep 2
    end
    return window
  else
    puts "Invalid."
    exit
  end
end
