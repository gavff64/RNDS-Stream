require "pathname"

Game = Struct.new(:appid, :name) # make each game entry an object in order to cleanly contain its app id and name

def steam_find_launch
  ignored_entries = %w[Proton Runtime Redistributables]
  games = []

# look at every .acf manifest file in the steamapps directory, read the "appid" and "name" of every one and list it
  Pathname("~/.local/share/Steam/steamapps").expand_path.glob("*.acf").each do |manifest|
    appid = manifest.basename.to_s[/\d+/]
    name = manifest.read[/"name"\s+"([^"]+)"/, 1]
    games << Game.new(appid, name) unless ignored_entries.any? { |word| name.include?(word) }
  end

  games.each_with_index do |game, index|
    puts "#{index + 1}. #{game.name}"
  end

  print "Pick a game: "

  if (number = gets.strip.to_i).between?(1, games.length)
    game = games[number - 1]
    Thread.new do
      puts
      puts "Launching #{game.name}..."
      system("steam", "steam://rungameid/#{game.appid}", out: File::NULL, err: File::NULL) # silence output
    end

    until (window = `wmctrl -l`.downcase.lines.find {|line| line.include?(game.name.downcase)})
      sleep 2
    end
    return window
  else
    puts "Invalid."
    exit
  end
end
