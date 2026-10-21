#===============================================================================
# Differentiating Duplicates - entry point
#   Loads scripts/*.rb in name order. Runs once.
#===============================================================================
return if defined?(::DiffDupes::LOADED)

module DiffDupes
  LOADED  = true
  ROOT    = File.dirname(File.expand_path(__FILE__))
  VERSION = (File.read(File.join(ROOT, "mod.json"))[/"version"\s*:\s*"([^"]+)"/, 1] rescue nil) || "?"
end

# One broken file is logged and skipped; the rest of the mod still loads
Dir[File.join(DiffDupes::ROOT, "scripts", "*.rb")].sort.each do |f|
  next if File.basename(f) == "030_Ability_Text.rb"   # 0.5.0 file, now 030_Texts.rb (left by an unzip over an old copy)
  begin
    load f
  rescue ScriptError, StandardError => e
    DiffDupes.log("#{File.basename(f)} not loaded: #{e.class}: #{e.message.lines.first.to_s.strip}") if DiffDupes.respond_to?(:log)
  end
end
DiffDupes.log("Differentiating Duplicates #{DiffDupes::VERSION} loaded")
