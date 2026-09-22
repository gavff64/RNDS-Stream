require "pathname"

def prism_games
  instances = []
  installs = [
    ["Prism Flatpak", "~/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances", ["flatpak", "run", "org.prismlauncher.PrismLauncher"]],
    ["Prism", "~/.local/share/PrismLauncher/instances", ["prismlauncher"]]
  ]

  installs.each do |source, path, launcher|
    Pathname(path).expand_path.glob("*/instance.cfg").each do |config|
      folder = config.dirname.basename.to_s
      name = config.read[/^name=(.+)$/, 1] || folder
      instances << Game.new(source, name.strip, "minecraft", launcher + ["--launch", folder])
    end
  end

  instances
end
