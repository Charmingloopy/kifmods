#===============================================================================
# Megas – Mega Evolution for KIF
#   Entry point. Loads the data, then scripts/*.rb in name order.
#   Safe to load again (F12 soft reset runs every script again): constants are
#   set once, every hook re-applies its def behind a guarded alias.
#===============================================================================
module Megas
  LOADED  = true unless defined?(LOADED)
  ROOT    = File.dirname(File.expand_path(__FILE__)) unless defined?(ROOT)
  VERSION = ((File.read(File.join(ROOT, "mod.json"))[/"version"\s*:\s*"([^"]+)"/, 1] rescue nil) || "?") unless defined?(VERSION)

  def self.log(msg)
    KIF.log("[Megas] #{msg}") if defined?(KIF) && KIF.respond_to?(:log)
  end
end

load File.join(Megas::ROOT, "data", "megas_data.rb") unless defined?(Megas::DATA)
load File.join(Megas::ROOT, "data", "shop.rb") unless defined?(Megas::SHOP)
# One broken file is logged and skipped; the rest of the mod still loads
Dir[File.join(Megas::ROOT, "scripts", "*.rb")].sort.each do |f|
  begin
    load f
  rescue ScriptError, StandardError => e
    Megas.log("#{File.basename(f)} not loaded: #{e.class}: #{e.message.lines.first.to_s.strip}")
  end
end
Megas.log("Megas #{Megas::VERSION} loaded (#{Megas::DATA.length} Megas)")
