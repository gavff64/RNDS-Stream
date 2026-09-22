require "pathname"

def steam_games
  ignored_entries = %w[Proton Runtime Redistributables]
  games = []
  seen = []
  installs = [
    ["Steam", "~/.local/share/Steam/steamapps", ["steam"]],
    ["Steam Flatpak", "~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps", ["flatpak", "run", "com.valvesoftware.Steam"]],
    ["Steam Flatpak", "~/.var/app/com.valvesoftware.Steam/data/Steam/steamapps", ["flatpak", "run", "com.valvesoftware.Steam"]]
  ]

  installs.each do |source, path, launcher|
    Pathname(path).expand_path.glob("*.acf").each do |manifest|
      appid = manifest.basename.to_s[/\d+/]
      name = manifest.read[/"name"\s+"([^"]+)"/, 1]
      next unless appid && name
      next if ignored_entries.any? { |word| name.include?(word) }
      next if seen.include?([source, appid])

      seen << [source, appid]
      games << Game.new(source, name, name, launcher + ["steam://rungameid/#{appid}"])
    end
  end

  games
end
