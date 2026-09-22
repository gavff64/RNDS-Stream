require "pathname"

def steam_games
  ignored_entries = %w[Proton Runtime Redistributables]
  games = []

  Pathname("~/.local/share/Steam/steamapps").expand_path.glob("*.acf").each do |manifest|
    appid = manifest.basename.to_s[/\d+/]
    name = manifest.read[/"name"\s+"([^"]+)"/, 1]
    next unless name
    next if ignored_entries.any? { |word| name.include?(word) }

    games << Game.new("Steam", name, name, ["steam", "steam://rungameid/#{appid}"])
  end

  games
end
