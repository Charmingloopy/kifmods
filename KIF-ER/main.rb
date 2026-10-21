#===============================================================================
# KIF: Elite Redux – Elite Redux innates and choice abilities for KIF
#   Entry point. Loads the generated data, then scripts/*.rb in name order.
#   Runs once, whether KIF or Mod Manager loads it (mod.json lists it).
#===============================================================================
return if defined?(::KIFER::LOADED)

module KIFER
  LOADED  = true
  LOAD_ERRORS = []   # scripts that failed to load (kit test s_910)
  ROOT    = File.dirname(File.expand_path(__FILE__))
  # version from mod.json, so there is one place to change it
  VERSION = (File.read(File.join(ROOT, "mod.json"))[/"version"\s*:\s*"([^"]+)"/, 1] rescue nil) || "?"
end

load File.join(KIFER::ROOT, "data", "er_data.rb")
load File.join(KIFER::ROOT, "data", "er_moves.rb")
# One broken file is logged and skipped; the rest of the mod still loads
Dir[File.join(KIFER::ROOT, "scripts", "*.rb")].sort.each do |f|
  begin
    load f
  rescue ScriptError, StandardError => e
    KIFER::LOAD_ERRORS << "#{File.basename(f)}: #{e.class}: #{e.message.lines.first.to_s.strip}"
    KIFER.log("#{File.basename(f)} not loaded: #{e.class}: #{e.message.lines.first.to_s.strip}") if KIFER.respond_to?(:log)
  end
end
KIFER.log("KIF: Elite Redux #{KIFER::VERSION} loaded (#{KIFER::SPECIES_DATA.length} species)")
