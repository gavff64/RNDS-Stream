require "pathname"

def prism_games
  instances = []
  configs = []

  configs += Pathname("~/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances").expand_path.glob("*/instance.cfg")
  configs += Pathname("~/.local/share/PrismLauncher/instances").expand_path.glob("*/instance.cfg")

  configs.each do |config|
    folder = config.dirname.basename.to_s
    name = config.read[/^name=(.+)$/, 1] || folder
    instances << Game.new("Prism", name.strip, "minecraft", ["flatpak", "run", "org.prismlauncher.PrismLauncher", "--launch", folder])
  end

  instances
end
